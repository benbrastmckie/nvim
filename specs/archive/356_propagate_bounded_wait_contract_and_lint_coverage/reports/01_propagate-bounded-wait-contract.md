# Research Report: Task #356

**Task**: 356 - Propagate bounded-wait contract and add lint coverage
**Started**: 2026-10-07T00:00:00Z
**Completed**: 2026-10-07T00:00:00Z
**Effort**: medium
**Dependencies**: None (explicitly no dependency edges to related open tasks; see Context & Scope)
**Sources/Inputs**: Codebase (agent-system/extensions source store), existing lint script and its
test fixtures, agent-template.md, bounded-build-waiter.md / external-process-wait.md pattern
docs, no-task-references-bullet.md / plan-status-ownership.md canonical-fragment precedent
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Coverage gap RE-CONFIRMED exactly as measured at task creation.** Re-running the stated
  reproduce command today against the source store gives the identical 3-covered / 14-missing
  split: `core/agents/general-implementation-agent.md`, `lean/agents/lean-implementation-agent.md`,
  and `lean/agents/lean-implementation-hard-agent.md` carry the contract; the same 14 files named
  in the dispatch do not. No divergence from the recorded figures.
- **Item 1 ruling: no pre-existing universally-included pointer file exists (option (a) is
  unavailable as literally stated), and the contract's real content is too long to duplicate in
  full 14 times.** The established, already-proven mechanism in this exact codebase — a short,
  literal, lint-verified MUST/MUST-NOT bullet pair copied into each agent body, sourced from one
  canonical "generated-copy" fragment — is the right shape, not a bespoke new design. It is the
  same shape `lint-agent-contracts.sh` Check C (`no-task-references-bullet.md`) and Check G
  (`plan-status-ownership.md`) already use for exactly this kind of propagation problem.
- **A hard, evidence-backed reason literal copy is required, not a pointer:**
  `no-task-references-bullet.md`'s own header states this was proven empirically for this
  codebase: "`@`-references inside an agent body do not auto-resolve when Claude Code spawns a
  subagent." A pointer to another agent's file, or to a pattern doc the target agent does not
  already load, will not reliably reach the dispatched agent's behavior.
- **The fragment can live in an existing file, so no new document is required.**
  `context/patterns/bounded-build-waiter.md` already describes itself as owning "the idiom," and
  the existing contract prose in `general-implementation-agent.md` already names it as the layer
  the MUST/MUST-NOT defers to. Appending a short "canonical agent-contract bullet" section there
  — rather than creating a new `context/contracts/*.md` file — satisfies the stated acceptance
  constraint that net document count not increase.
- **Item 3 (hard variants): no inheritance mechanism exists.** Hard-mode agent files are fully
  independent prose, not includes of their non-hard sibling (confirmed by direct inspection and
  by `books-implementation-hard-agent.md`'s own self-description, "Extends
  `books-implementation-agent` with three behavioral additions" — a prose claim, not a file
  reference). Both hard variants in the 14-file list need the bullet independently.
- **Item 4 (research agents): they are plausibly exposed to the same defect, but this task's
  measured evidence and acceptance criteria are implementation-scoped.** `general-research-agent.md`
  itself already demonstrates the identical partial-coverage shape this task is fixing for
  implementation agents — it carries the external/remote-wait discipline but zero occurrences of
  the local-background-wait discipline — which is evidence FOR eventually extending this same
  mechanism to research agents, not a reason to silently drop the question. Ruled: out of this
  task's scope, recorded explicitly as a follow-up recommendation using the identical mechanism.

## Context & Scope

This is a propagation-and-enforcement task, not an authorship task. The contract text (a MUST to
use `bounded-build-waiter.md`'s canonical idiom verbatim when backgrounding a local
verification/gate/build/test process, and a MUST NOT on `Bash(run_in_background: true)` or arming
a `Monitor` to watch such a process from within a dispatched subagent) already exists, is already
correct, and lives in `core/agents/general-implementation-agent.md` (its "Local Long-Running
Command Discipline" block, inside Stage 4's context-pressure section). This research verifies the
measured gap, settles where the single shared home for propagation should live, and specifies
precisely how `core/scripts/lint/lint-agent-contracts.sh` should assert coverage so the gap cannot
silently reopen.

Three related tasks exist in the same area by design, with no dependency edges: the completed
work that landed the contract in its two current homes and added a post-return staleness check;
the open task asking why advisory prose and an advisory PostToolUse hook fail to *bind* a
dispatched agent to text it has already read (a different question than coverage); and the open
task adding a PreToolUse gate for a sibling waiter rule. This task answers only "is the contract
text present where it needs to be, and is that presence mechanically checked" — it assumes, per
the natural experiment cited in the dispatch, that presence is sufficient when the agent actually
reads its own prompt, which is the normal case for a freshly dispatched subagent.

## Findings

### Codebase Patterns

**Re-confirmed coverage measurement** (command: `cd agent-system/extensions && for f in $(find .
-name '*implementation*agent.md' | sort); do echo "$(grep -c run_in_background "$f") $(grep -c
bounded-build-waiter "$f") $f"; done`), run fresh during this research pass:

```
0 0 books/agents/books-implementation-agent.md
0 0 books/agents/books-implementation-hard-agent.md
2 4 core/agents/general-implementation-agent.md
0 0 cslib/agents/cslib-implementation-agent.md
0 0 cslib/agents/cslib-implementation-hard-agent.md
0 0 cslib/agents/pr-review-implementation-agent.md
0 0 email/agents/email-implementation-agent.md
0 0 latex/agents/latex-implementation-agent.md
5 1 lean/agents/lean-implementation-agent.md
6 2 lean/agents/lean-implementation-hard-agent.md
0 0 nix/agents/nix-implementation-agent.md
0 0 nvim/agents/neovim-implementation-agent.md
0 0 python/agents/python-implementation-agent.md
0 0 rust/agents/rust-implementation-agent.md
0 0 typst/agents/typst-implementation-agent.md
0 0 web/agents/web-implementation-agent.md
0 0 z3/agents/z3-implementation-agent.md
```

Identical to the dispatch's recorded figures — no divergence to report.

**No pre-existing universally-included "always load" pointer file exists across all 17**
(testing item 1(a) directly, since "several extensions' agents have divergent always-load lists"
was flagged as a thing to verify, not assume):

- `@.claude/context/formats/return-metadata-file.md` is the only context reference present in
  all 17 files — but it is a metadata-schema document, topically unrelated to process-wait
  discipline. Reusing it as the contract's home would conflate two unrelated concerns.
- `@.claude/context/contracts/phase-closure.md` and `@.claude/context/contracts/pre-edit-gate.md`
  are present in 15 of 17 — missing from exactly `cslib/agents/pr-review-implementation-agent.md`
  and `email/agents/email-implementation-agent.md`, both of which are non-phased agents by design
  (pr-review has a single flat `## Stage N` sequence with no phase-marker loop; email's plan
  execution has no `### Phase N: [MARKER]` heading to manage). These are also 2 of the 14 files
  this task must cover, so even the closest-to-universal existing pointer would still need a
  fresh addition in exactly the two hardest cases.
- Conclusion: option (a), as literally specified ("a shared always-load context pointer that
  every implementation agent already includes"), does not exist today. It is ruled out, not
  assumed.

**The literal-copy-plus-lint-verified-fragment pattern is already established in this exact
lint script, for exactly this kind of problem**, and its rationale is directly on point. From
`context/contracts/no-task-references-bullet.md`'s own header (added for an earlier, structurally
identical propagation problem — a MUST-NOT bullet needed in ~20 agent files):

> "This fragment is a generated-copy source, read by a human or a lint script — it is NOT
> `@`-imported into agent bodies at spawn time. Research for this task... proved empirically, and
> against the official sub-agents documentation, that `@`-references inside an agent body do not
> auto-resolve when Claude Code spawns a subagent. An agent body carries a **literal copy** of the
> bullet text below; `lint-agent-contracts.sh` Check C keeps every copy in sync by comparing it
> against this file, not against a hardcoded string baked into the lint."

This is decisive evidence against a pure pointer-based design (e.g., "add one line in each
agent's Context References pointing at `general-implementation-agent.md`'s section") for the
*behavioral* MUST/MUST-NOT core of the contract: a pointer to another agent's specific internal
section is not something any agent's own execution-flow instructions tell it to fetch, unlike the
"Context References... always load `path`" convention (which works only because the *agent's own
body* explicitly instructs it, at Stage 1/2, to call `Read` on that path — a manual step the
agent reliably performs, not an automatic harness-level inlining).
`lint-agent-contracts.sh` Check G (`plan-status-ownership.md`) is the second precedent for the
identical shape, built after Check C, for an unrelated bullet, confirming this is the house style
rather than a one-off.

**`lint-agent-contracts.sh` already has the exact scaffolding a new check needs**: a shared
`enumerate_dispatchable_agents`/`is_dispatchable_agent` detector, a `rel_path` helper, and two
live precedents (Checks C and G) of: (1) a small canonical fragment file with a "Copy this exact
text" block, (2) a curated `IN_SCOPE_RELATIVE_PATHS` bash array (not a mechanically-derived glob —
scope here is a judgment call, exactly as Check C's and G's own comments say), (3)
`grep -qF` of the fragment's extracted text against each in-scope file. The script is wired into
`verify-deploy.sh` (a real gate, not an orphan), and `core/scripts/tests/test-lint-agent-contracts.sh`
already has the fixture-tree convention this new check should extend: one positive "conforming"
fixture, one "missing" negative fixture, and (per Check G's own test) a "near-miss paraphrase"
fixture that proves the match is verbatim, not loose.

**Hard variants are independent prose, with no inheritance mechanism.**
`books-implementation-hard-agent.md` explicitly says it "Extends `books-implementation-agent`
with three behavioral additions" — but this is a documentation claim, not a file inclusion; there
is no `@`-reference or generation pipeline linking the hard file back to its non-hard sibling
found anywhere in either file. Both already appear independently in the measured-missing list
(`books-implementation-hard-agent.md` and `cslib-implementation-hard-agent.md`), which is itself
direct evidence of the "no inheritance" finding — if inheritance existed, fixing the non-hard
sibling would already have fixed the hard one, and it measurably has not.

**Research agents show the identical partial-coverage shape, which is evidence relevant to item
4.** `core/agents/general-research-agent.md` (the agent type this very research dispatch is
running under) already carries the external/remote-wait discipline almost verbatim (its own
Stage 3.5/3.6, matching `external-process-wait.md`'s Rules 1-3/6) but has zero occurrences of
`bounded-build-waiter` and zero of a local-background MUST/MUST-NOT. `lean-research-agent.md` and
`lean-research-hard-agent.md` each have exactly one `run_in_background` occurrence, but it is the
Lean-specific *sanctioned* background-build path (`lake build` routed through the build guard,
per `context/project/lean4/operations/long-builds.md`), not the general prohibition — i.e. a
different, legitimate mechanism, not partial coverage of this contract. Several research agents
(`nix-research-agent.md`, `rust-research-agent.md`, `latex-research-agent.md`) have Bash access
explicitly for "verification commands," "nix flake check," "nixos-rebuild" — commands that could
plausibly be backgrounded the same unsafe way. None of the non-Lean research agents carry either
half of the contract today.

**`pr-review-implementation-agent.md` and `email-implementation-agent.md` have the weakest
current exposure to the actual defect** (neither runs a local build/verification process that
would plausibly be backgrounded in its current body — pr-review's Stage 4 is Read/Edit only;
email's Stage 4 "Verify" diffs wrapper output, not a backgrounded build), but both are explicitly
named in the dispatch's 14-file acceptance list and both already have Bash tool access, so
propagating preemptively is cheap defensive coverage against the next person who adds a
verification step to either — exactly the "a fifteenth agent added later would miss it again"
risk the dispatch names.

### External Resources

Not applicable — this is a closed, internal meta-task over the source store; no external
documentation or best-practice research was needed or consulted.

## Recommendations

1. **Item 1 (shared home):** Keep the full contract prose (ruling, three-way fork, rationale)
   solely in `general-implementation-agent.md`, unedited — do not touch that file; it is declared
   correct and is already claimed by two other open tasks' `file_scope`. Append a new, short
   "canonical agent-contract bullet" section to the *existing* `context/patterns/bounded-build-waiter.md`
   file (an edit, not a new document), structured like `no-task-references-bullet.md`/
   `plan-status-ownership.md`: a "Generated-Copy Source, Not an `@`-Import" explainer, a
   Classification Rule naming which agents must carry it, and a fenced "Copy this exact text"
   block containing a short MUST + MUST NOT bullet pair (2-4 lines, not the full ~60-line block)
   for each target agent's own `## Critical Requirements` MUST/MUST NOT list.
2. **Item 1 (template complement):** Add the same short bullet to the `### Implementation Agent`
   subsection of `core/context/templates/agent-template.md` — the canonical structure
   `meta-builder-agent` actually generates new agents from (confirmed by
   `core/docs/templates/agent-template.md`'s own cross-reference: "the canonical structure
   `meta-builder-agent` uses... see `.claude/context/templates/agent-template.md`"). This is a
   forward-looking complement only — it does not by itself fix any of the 14 existing files, and
   the plan must not treat it as a substitute for propagation.
3. **Item 2 (lint):** Add a new Check (next free letter after G) to `lint-agent-contracts.sh`,
   structurally identical to Check C/G: a `BOUNDED_WAIT_FRAGMENT_FILE` constant pointing at the
   amended `bounded-build-waiter.md`, an `IN_SCOPE_RELATIVE_PATHS` array containing exactly the 14
   files (both hard variants included per item 3's ruling), `grep -F` extraction of the fragment's
   canonical text, and `grep -qF` verification per in-scope file. Record
   `general-implementation-agent.md`, `lean-implementation-agent.md`, and
   `lean-implementation-hard-agent.md` as an explicit, reasoned exclusion list (they already carry
   the contract via distinct, already-correct wording — lean's being a legitimately different,
   domain-adapted sanctioned-background path — not an unfixed gap), mirroring Check E/F's
   precedent of recorded exclusions confirmed by reading, never inferred.
4. **Item 2 (tests):** Extend `core/scripts/tests/test-lint-agent-contracts.sh` with the same
   three-fixture shape Check G used: a conforming positive fixture, a missing-bullet negative
   fixture, and a near-miss-paraphrase fixture proving the match stays verbatim. This directly
   satisfies the acceptance bullet requiring a fixture or deliberate temporary removal to
   demonstrate the FAIL/PASS behavior.
5. **Item 3 (hard variants):** Rule explicitly, in the plan and in a short note near the new
   fragment's Classification Rule, that hard-mode variants do not inherit from their non-hard
   sibling by any existing mechanism and must be listed independently in the lint's in-scope set
   — which this research has already done (both hard files are in the 14-file list).
6. **Item 4 (research agents):** Record explicitly, in the plan, that research agents are
   plausibly exposed to the identical defect class (evidenced by `general-research-agent.md`'s
   own partial coverage and several research agents' Bash-based verification-command access), but
   that propagating to them is out of this task's chartered acceptance criteria (which name only
   "implementation agent" and the 14 specific files). Recommend a dedicated follow-up task that
   reuses the identical fragment-and-lint-check mechanism this task establishes, scoped to
   research agents, rather than silently dropping the question or silently expanding this task's
   acceptance surface.
7. **Shellcheck:** Any shell edit to `lint-agent-contracts.sh` or
   `test-lint-agent-contracts.sh` must stay clean per `context/standards/shell-strict-mode.md`,
   consistent with the acceptance bullet.

## Decisions

- **Decision (Item 1 — home):** The contract's explanatory prose stays exactly where it is
  (`general-implementation-agent.md`, untouched). The propagation vehicle is a short MUST/MUST-NOT
  bullet pair, literally copied into each of the 14 target agent bodies, sourced from one
  canonical fragment appended to the existing `context/patterns/bounded-build-waiter.md` file —
  not a new `context/contracts/*.md` file, to honor the "net document count does not increase"
  acceptance constraint, and not a bare `@`-pointer, because `@`-references into another agent's
  file do not auto-resolve for a dispatched subagent (proven precedent cited above). Option (a) —
  reuse of a pre-existing universal pointer — is rejected because no such file exists (nearest
  candidate, `phase-closure.md`/`pre-edit-gate.md`, is missing from exactly 2 of the 14 target
  files, by design, since those two agents are non-phased). Option (c) — fourteen independent,
  unsynchronized copies — is rejected per the dispatch's own anti-proliferation principle and is
  not what is being proposed here: the *fragment* is the one shared home that is hand-edited; the
  14 copies are lint-verified-identical, generated-copy artifacts, exactly like Check C's and
  Check G's existing precedent.
- **Decision (Item 1 — template):** Adopted as a forward-looking complement only. Edit
  `core/context/templates/agent-template.md`'s `### Implementation Agent` variant subsection to
  carry the same short bullet, so a newly `/meta`-generated implementation agent inherits it by
  construction. Explicitly recorded: this does not fix any of the 14 existing files and must not
  be treated as satisfying item 2's lint-coverage requirement for them.
- **Decision (Item 2 — lint mechanism):** A new curated-in-scope-list + fragment-extraction +
  `grep -qF` check, following Check C/G's exact shape — not a mechanically-derived glob over all
  `*implementation*agent.md` files, because three of the 17 are legitimate, already-correct,
  differently-worded exclusions that a literal-text check cannot uniformly recognize without
  producing false failures (this is precisely the scenario item 2 itself anticipates: "the lint
  must follow the pointer rather than grep for the prohibition's literal words, or it will report
  false failures on every correctly-wired agent" — generalized here to "every already-correctly-
  worded agent").
- **Decision (Item 3 — hard variants):** Hard-mode agents do not inherit from their non-hard
  sibling through any existing file-reference or generation mechanism; each must carry its own
  literal copy of the bullet and must be listed independently in the lint's in-scope set. Both
  hard variants are already part of the 14-file target list.
- **Decision (Item 4 — research agents):** Out of scope for this task's propagation and lint
  changes. The question is not silently dropped: research agents are plausibly equally exposed
  (direct evidence: `general-research-agent.md`'s own partial coverage), and a follow-up task
  reusing this task's exact mechanism is the recommended path, rather than widening this task's
  acceptance criteria (which name only implementation agents and a specific 14-file list) or
  ignoring the question.

## Risks & Mitigations

- **Risk**: A literal-text lint check is brittle to minor rewording during editing (e.g., fixing a
  typo in the canonical bullet breaks every copy at once, surfacing as 14 simultaneous lint
  failures). **Mitigation**: this is the same risk Check C/G already carry today and have
  operated with; the fragment file is explicitly the one place to edit, and a wording change is
  expected to be followed by a mechanical re-propagation pass, not treated as a surprise.
- **Risk**: Appending new content to `bounded-build-waiter.md` could be read as violating the
  dispatch's non-goal "Do NOT add a new pattern document." **Mitigation**: the addition is a
  propagation-fragment section within the *existing* pattern document (which already names itself
  the idiom's canonical owner), not a second pattern document describing a different idiom; no
  new document is created, consistent with that non-goal and with "net document count does not
  increase."
- **Risk**: Treating `pr-review-implementation-agent.md`/`email-implementation-agent.md` as
  in-scope despite weak current exposure could be second-guessed as over-propagation.
  **Mitigation**: both are explicitly named in the dispatch's acceptance-gating 14-file list;
  this research does not have license to narrow that list, only to rule on the *mechanism*. The
  weak-exposure finding is recorded as a rationale (defensive/preventive coverage against a
  future Bash verification step), not as grounds for exclusion.
- **Risk**: A future contributor adds an 18th implementation agent and still misses the contract,
  because the new lint check's `IN_SCOPE_RELATIVE_PATHS` array, like Check C/G's, is curated by
  hand rather than mechanically derived from all `*implementation*agent.md` files. **Mitigation**:
  this is an accepted, explicit trade-off already made twice in this codebase (Check C, Check G)
  for the same reason (some agents are legitimate exclusions a mechanical glob cannot
  distinguish); it is out of this task's scope to fix the broader "curated list drifts" problem,
  but the plan should at minimum point a comment at the reproduce command in this report so a
  future auditor can re-run it.

## Context Extension Recommendations

- **Topic**: Agent-contract propagation pattern (literal-copy-plus-lint-fragment).
- **Gap**: The "Generated-Copy Source, Not an `@`-Import" rationale and the literal-copy-plus-lint
  pattern are currently documented only inside two single-purpose fragment files
  (`no-task-references-bullet.md`, `plan-status-ownership.md`), each framed around its own
  specific bullet rather than as a general, reusable pattern. A third instance (this task) and a
  plausible fourth (the research-agent follow-up recommended above) suggest the pattern itself —
  not just its two existing applications — is now reusable knowledge.
- **Recommendation**: Not a candidate for this task to create (would itself increase document
  count against this task's own acceptance constraint). Recorded here for a future
  `context/patterns/` or `context/contracts/` addition, once a third or fourth concrete instance
  exists, to extract the general "how to propagate a short behavioral bullet across many agent
  bodies with lint-verified sync" pattern out of its first two single-purpose homes.

## Appendix

- Search queries / commands used:
  - `for f in $(find . -name '*implementation*agent.md' | sort); do echo "$(grep -c
    run_in_background "$f") $(grep -c bounded-build-waiter "$f") $f"; done` (coverage
    re-confirmation, implementation agents)
  - Same command adapted for `*research*agent.md` plus a third `external-process-wait` column
    (research-agent partial-coverage finding)
  - `grep -n "phase-closure.md\|pre-edit-gate.md\|return-metadata-file.md" <file>` across all 17
    implementation-agent files (universal-pointer-file test)
  - `diff core/docs/templates/agent-template.md core/context/templates/agent-template.md`
    (confirms two distinct template files with different purposes/audiences)
  - `grep -rln "lint-agent-contracts.sh"` (confirms the lint is wired into `verify-deploy.sh`,
    not orphaned, and has an existing test file)
- References:
  - `agent-system/extensions/core/agents/general-implementation-agent.md` (the contract's current
    home, "Local Long-Running Command Discipline" section)
  - `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` and
    `external-process-wait.md` (the two pattern docs; proposed amendment target)
  - `agent-system/extensions/core/context/contracts/no-task-references-bullet.md` and
    `plan-status-ownership.md` (the two existing precedents for the literal-copy-plus-lint-fragment
    shape, including the `@`-import non-resolution evidence)
  - `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (Checks C, E, F, G as the
    direct structural precedent for the new check)
  - `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` (fixture-tree
    convention to extend)
  - `agent-system/extensions/core/context/templates/agent-template.md` (template complement
    target, "### Implementation Agent" subsection)
  - `agent-system/extensions/core/agents/general-research-agent.md`,
    `agent-system/extensions/lean/agents/lean-research-agent.md` (item 4 evidence)
