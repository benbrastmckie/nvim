# Research Report: Task #431

**Task**: 431 - Durable record for gate-enforced verbatim fragments
**Started**: 2026-11-06
**Completed**: 2026-11-06
**Effort**: small (single new context file + one index-entries.json append)
**Dependencies**: None (ordered after the systematic-corpus-efficiency record's territory for scripts/lint/, per the dispatch's declared edge; this phase touches no file in that territory)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`, `lint-postflight-boundary.sh`, `context/standards/task-reference-exemptions.md`, `context/standards/record-version-exemptions.md`, `context/standards/documentation-standards.md`, `docs/reference/standards/agent-frontmatter-standard.md`, `index-entries.json`
- Live gate runs (baseline finding counts, this session)
**Artifacts**:
- This report: `specs/431_durable_record_for_gate_enforced_verbatim_fragments/reports/01_gate-enforced-fragment-duplication-record.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The constraint is real and currently undocumented outside a single task's own plan: two gates
  in `agent-system/extensions/core/scripts/lint/` read fragment files at runtime and FAIL any
  in-scope contract that lacks a verbatim copy of their content (a bullet/template) or a literal
  heading. Collapsing that duplication during a corpus-reduction pass changes what the gate
  finds, which is a behavior change disguised as cleanup.
- The lints' own fragment-path variable set has already drifted since the originating plan
  recorded it: `lint-agent-contracts.sh` now resolves **six** variables (one is the standard
  document itself, five are bullet/template fragments), not the four-or-five the originating
  plan described — concrete, live proof that a hardcoded list in the new record would already be
  stale on day one. This confirms the plan's own requirement: the record must state a derivation
  rule, never a copied list.
- `index-entries.json` indexes only files under `context/`; `docs/reference/standards/
  agent-frontmatter-standard.md` has no entry there at all. This is the deciding fact for
  placement: a record living inside that `docs/` file would not satisfy the dispatch's
  REGISTRATION requirement (reachable through the context index) without adding a wholly new,
  non-precedented indexing path for a `docs/` file. **Recommendation: a new file under
  `agent-system/extensions/core/context/standards/`**, registered in `index-entries.json`
  exactly as `task-reference-exemptions.md` and `record-version-exemptions.md` already are.
- Baseline gate output captured this session for later before/after diffing (VERIFY (b)):
  `lint-agent-contracts.sh` → Passed 421 / Warnings 15 / Failed 0; `lint-postflight-boundary.sh`
  (run with no arguments, so it scans the **deployed** `.claude/skills` + `.claude/extensions`
  tree, not the source store) → Files checked 0, violations 0 (the deployed tree currently has
  no `SKILL.md` files matching its scan roots in this repo's layout at this time). The deploy-
  freshness note on this dispatch already flags `core`/`lean` as stale in the deployed tree, so
  an implementer re-running this check for VERIFY (b) should run it against freshly deployed
  skills, or pass explicit source-tree-relative paths, not rely on the no-argument default
  silently scanning a stale or structurally different target.

## Context & Scope

This is a `meta` task whose deliverable is a new, discoverable context record under
`agent-system/extensions/core/context/` (the source store; never the deployed `.claude/` tree —
see `rules/source-store-deploy-boundary.md`). The task does not touch, and must not change, the
behavior of either enforcing gate or any fragment's text. The research question is narrowly:
where should the record live, what must it say to satisfy the dispatch's four SCOPE
requirements, and what evidence from the live corpus supports that placement and content.

The dispatch already performed the duplicate-check and declared the territory edge; this report
does not re-litigate those decisions. It re-derives the mechanics (since "line numbers move") and
resolves the one open decision the dispatch explicitly left to this phase: **PLACEMENT**.

## Findings

### Codebase Patterns

**Mechanic 1 — `lint-agent-contracts.sh`'s fragment-path variables (re-derived; six, not
four/five).** Lines ~133–139 in the current source store resolve:

```
STANDARD_FILE                   = docs/reference/standards/agent-frontmatter-standard.md
FRAGMENT_FILE                    = context/contracts/no-task-references-bullet.md
ARTIFACTS_TEMPLATE_FRAGMENT      = context/contracts/return-meta-artifacts-template.md
PLAN_STATUS_OWNERSHIP_FRAGMENT   = context/contracts/plan-status-ownership.md
BOUNDED_WAIT_FRAGMENT            = context/patterns/bounded-build-waiter.md
MODIFIED_FILES_FRAGMENT          = context/contracts/modified-files-bullet.md
```

`STANDARD_FILE` is the standard document itself (consulted for Checks A/B, not a bullet/template
fragment read-and-compared verbatim); the other five are genuine verbatim-fragment variables, one
more than the originating plan's own count (it named four fragment paths plus the standard file,
i.e. five variables total — `MODIFIED_FILES_FRAGMENT`/Check L is newer). This is the clearest
possible confirmation, found live rather than asserted, of the plan's own warning: a hardcoded
list copied into a durable record would already be one entry short at authoring time, and would
rot further in the dangerous direction (claiming a fragment safe to collapse after the lint
started reading a different, newer one).

**Mechanic 2 — what each of the two named gates enforces, per their own header prose:**
- `lint-agent-contracts.sh` Check C/F/G/L each read an expected bullet or JSON-template string
  from one of the fragment files above *at runtime* and FAIL any in-scope dispatchable agent
  contract whose file does not carry a verbatim copy of that text. The header comment states the
  rationale directly: "so the fragment stays load-bearing rather than decorative." Each check
  also carries its own curated in-scope/exclusion arrays (e.g. `EXCLUDED_ARTIFACTS_TEMPLATE_
  RELATIVE_PATHS` at line ~389, naming `code-reviewer-agent.md` and `literature-agent.md` as the
  two agents that never write `.return-meta.json` at all) — these in-scope/exclusion arrays are a
  *different* mechanism (which agents are checked) from the fragment-path variables (what text is
  expected); the new record's derivation rule concerns the latter, not the former.
- `lint-postflight-boundary.sh` asserts a **literal heading string**,
  `^## MUST NOT \(Postflight Boundary\)`, via `grep -qE` (its `has_postflight_boundary_section`
  function, around line 76–82), and records a missing heading as a named violation (around line
  169–174). Its own header comment states why it is anchored to that specific heading text and
  not any `## MUST NOT` heading: a skill may legitimately carry an unrelated `MUST NOT` section
  (the header names `skill-orchestrate`'s `## MUST NOT (Context Flatness Constraint)` as the
  concrete example) — collapsing or templating the heading text would silently change what this
  gate finds.

**Mechanic 3 — scope of the no-fragment-collapse constraint is narrower than "all agent/skill
duplication."** Both gates only enforce against specific, named fragment files or a specific
heading string — not against markdown duplication in general. A consolidation pass can still
safely collapse duplication that neither gate reads. The record's job is to let a future pass
tell the two classes apart *without* re-deriving this research from scratch, via the derivation
rule (read the lints' own variables/heading assertions), not by consulting a copied list.

**Placement candidates, weighed:**

1. **`agent-system/extensions/core/context/standards/` (new file)** — the two nearest-precedent
   siblings, `task-reference-exemptions.md` and `record-version-exemptions.md`, already live
   here. Both pair a principle with an exemption/exclusion taxonomy and name a single mechanical
   source of truth the taxonomy must be read from, not copied into — the exact shape this new
   record needs (principle: don't collapse gate-enforced duplication; derivation rule: read the
   lints' own variables; worked examples: the two named gates). Unlike those two companions,
   this record has no paired always-eager `rules/*.md` prohibition to companion — it is a
   narrower domain fact for consolidation-pass planning, not a repo-wide deliverable constraint —
   so it stands alone in this directory rather than explicitly companioning a rule, which is a
   difference in kind from its two siblings but not a reason to place it elsewhere: the directory
   already holds other standalone domain-fact records (e.g. `postflight-tool-restrictions.md`,
   `shell-script-testing.md`) that companion no `rules/*.md` file either.
2. **A new section inside `docs/reference/standards/agent-frontmatter-standard.md`** — rejected.
   That file is itself one of the files `lint-agent-contracts.sh` reads (`STANDARD_FILE`), so it
   is topically adjacent, but it lives under `docs/`, which `index-entries.json` does not index
   at all (confirmed: zero entries anywhere in the 171-entry index have a `docs/`-prefixed
   `path`; every indexed path is `context/`-relative). Placing the record there would fail the
   dispatch's own REGISTRATION requirement outright unless a new, unprecedented `docs/`-indexing
   mechanism were invented for this one file — out of scope and unjustified by anything else in
   the corpus.
3. **A pointer comment added to each enforcing lint's header, with the full record living
   elsewhere** — not a placement on its own (the dispatch frames it as an addendum to whichever
   placement is chosen, not an alternative to it). Viable as a *discovery-path* addition (see
   Decisions below) but the dispatch's own TERRITORY EDGE section flags that touching either
   lint's header lands inside the systematic-corpus-efficiency record's declared
   `scripts/lint/` directory-scope territory, ordered after this record for exactly that reason.
   This phase (research) does not touch `scripts/lint/`; an implement phase choosing to add such
   a pointer must do so only once that territory is clear, consistent with the dispatch's own
   ordering note.

**`index-entries.json` registration precedent (for option 1):** both sibling exemption records
are registered with an identical entry shape — `path` relative to `context/`, `domain: "core"`,
`subdomain: "standards"`, a one-line `summary`, `line_count`, `keywords`, `topics: ["quality"]`,
an empty `load_when` (no eager agent/command/task_type binding — these are on-demand reference
files), and `on_demand: true`. The new record's entry should follow this exact shape so a future
consolidation pass can find it by keyword search (`grep -i exclusion`, `grep -i verbatim`,
`grep -i duplicat`, etc. against `index-entries.json`'s `keywords`/`summary` fields) without
knowing the filename in advance — this is the REGISTRATION requirement's actual discovery
mechanism, not a formality.

**No existing file already covers this gap** (confirmed, not merely duplicate-checked by the
dispatch): neither `context/standards/` nor `docs/reference/standards/` contains any file whose
content states the general principle "some duplication is deliberate and gate-enforced, derive
the exclusion set from the lints, never hardcode it" as a standalone, named record — the closest
hits (`return-meta-artifacts-template.md`, `plan-status-ownership.md`, `no-task-references-
bullet.md`, `modified-files-bullet.md`, `bounded-build-waiter.md`, `anchor-pointer-convention.md`,
`agent-frontmatter-standard.md`) each document *themselves* and their own lint usage, but none
documents the cross-cutting constraint a future consolidation pass needs before it starts
touching any of them.

### External Resources

Not applicable — this is a purely internal-corpus documentation task with no external
dependency, library, or best-practice lookup involved.

## Recommendations

1. **Create** a new file at
   `agent-system/extensions/core/context/standards/gate-enforced-fragment-duplication.md` (name
   chosen to be found by a future searcher's most likely query terms — "gate", "enforced",
   "fragment", "duplication" — and to avoid collision with any existing filename; confirmed no
   collision exists). Structure it to mirror its two siblings:
   - A short "why this exists" principle statement: naming the exclusion class (verbatim-
     duplicated markdown a gate reads and enforces at runtime) and why collapsing it is a
     behavior change to the gate's finding set, not a cleanup, with the measured scale (roughly
     3,997 of 16,851 otherwise-removable lines, just under a quarter of the apparent reduction
     opportunity) carried as the motivating evidence for why a future pass will be tempted and
     needs to be stopped before it starts.
   - The **derivation rule**, stated as a rule, not a list: read each enforcing gate's own
     fragment-path variables (and, for the heading-based gate, its literal-heading assertion) at
     the time of the consolidation pass; never copy a path list into this record. State
     explicitly that this record's own worked examples (next bullet) are *illustrations of the
     class*, not an enumeration to extend when a new gate or fragment appears — the class grows
     by a future author adding a new worked example after independently re-deriving it from a
     gate's source, not by editing a canonical list here.
   - The two worked examples, each citing the gate by filename and the specific mechanism
     (fragment-path variable names for the first; the literal heading regex for the second) —
     written as *illustrations*, explicitly not as the record's own definition of the exclusion
     set, consistent with the derivation rule above.
   - A **discovery path** section: how a future consolidation/corpus-reduction/dedup/template-
     extraction task is expected to reach this record before planning. Two complementary
     mechanisms are available and neither alone is sufficient:
     (a) `index-entries.json` registration (keyword search finds it without knowing the
     filename), and
     (b) a terse pointer comment near the top of each enforcing lint's own header prose,
     referencing this record by path — the lints already carry extensive self-documenting header
     comments (confirmed above), so a one-line addition naming this record is a small, natural
     extension of an existing convention, not a new one. This second mechanism is the stronger
     guarantee (anyone reading the gate before changing related fragments sees the pointer
     directly) but, per the dispatch's TERRITORY EDGE note, touching `scripts/lint/` is not this
     research phase's territory and should be sequenced at implement time after confirming the
     systematic-corpus-efficiency record's territory claim on that directory is clear.
2. **Register** the new file in `index-entries.json`, appended to the existing 171-entry
   `entries` array (additive array append only — never a wholesale rewrite), using the exact
   shape of the two sibling entries shown above: `path: "standards/gate-enforced-fragment-
   duplication.md"`, `domain: "core"`, `subdomain: "standards"`, a one-line `summary`,
   `line_count` matching the finished file, `keywords` covering at minimum `exclusion-class`,
   `verbatim-duplication`, `gate-enforced`, `derivation-rule`, `corpus-consolidation`, `topics:
   ["quality"]`, empty `load_when`, `on_demand: true`.
3. **Do not** hardcode the fragment-path list inside the new record as a verification aid "just
   to be concrete" — Mechanic 1 above is direct, live evidence that such a list is already stale
   relative to the originating plan's own count, which is exactly the failure mode the dispatch's
   hard constraint (2) forbids.
4. **At VERIFY time**, run both gates before and after the new file lands and diff their output.
   For `lint-postflight-boundary.sh`, be aware it defaults (no arguments) to scanning the
   *deployed* `.claude/skills` + `.claude/extensions` tree, not the source store directly — an
   implementer should either redeploy first (this dispatch's own deploy-freshness note already
   flags `core`/`lean` as stale) or pass explicit paths, so the before/after diff is not
   confounded by an unrelated deploy-staleness difference between the two runs.

## Decisions

- **Placement decided: `agent-system/extensions/core/context/standards/gate-enforced-fragment-
  duplication.md`** (new file), on the strength of the index-entries.json-indexes-only-`context/`
  finding and the structural match to `task-reference-exemptions.md`/`record-version-
  exemptions.md`. `docs/reference/standards/agent-frontmatter-standard.md` is rejected as the
  sole home because it is unreachable through the context index as it stands.
- **The record will additionally recommend (not itself perform, per the territory edge) a
  pointer comment in each enforcing lint's header**, as a second discovery-path mechanism
  alongside index registration — this is noted as a Recommendation above rather than a Decision
  because it touches `scripts/lint/`, outside this research phase's role and inside a different
  record's declared territory per the dispatch.
- **The six current fragment-path variables in `lint-agent-contracts.sh` are documented in this
  report as re-derived evidence for the planning phase, not copied into the new durable record
  itself** — consistent with hard constraint (2).

## Risks & Mitigations

- **Risk**: a future consolidation pass still misses the record despite index registration,
  because it searches by a different keyword than the ones chosen. **Mitigation**: the
  recommended second discovery path (lint-header pointer comments) is the direct mitigation —
  anyone reading either gate's source before changing related fragments sees the pointer without
  needing to search the index at all. This is why the dispatch frames discovery path as "the
  component that decides whether the task actually closes the gap."
- **Risk**: an implementer, under time pressure, is tempted to inline the current six-variable
  list into the new record "for concreteness," reintroducing the staleness hazard this report
  demonstrates is already live. **Mitigation**: hard constraint (2) is restated explicitly in
  Recommendation 3 above, with the live evidence (Mechanic 1) as the concrete reason, not an
  abstract warning.
- **Risk**: `lint-postflight-boundary.sh`'s deployed-tree-by-default scan root makes a naive
  before/after diff at VERIFY time look falsely clean (0 files checked against a stale or
  differently-laid-out deployed tree) even if the gate would in fact fire against the source
  store post-redeploy. **Mitigation**: Recommendation 4 above names this explicitly and gives the
  two correct workarounds (redeploy first, or pass explicit paths).

## Context Extension Recommendations

- **Topic**: cross-cutting "why can't I collapse this duplication" guidance for corpus-reduction
  planning in general (this record covers only the two gates currently known to enforce verbatim
  fragments; a broader pattern — e.g. golden-file/fixture duplication enforced by a test rather
  than a lint — is plausible but not currently observed in this corpus and is out of scope here).
- **Gap**: no single file currently answers "before you start a dedup/consolidation pass over
  `agent-system/**`, what classes of apparent duplication are load-bearing?" This record answers
  it for one class; a future record could generalize once a second, structurally different class
  is observed (per the derivation-rule's own instruction not to pre-empt that).
- **Recommendation**: no new context file beyond the one this report already recommends; revisit
  only if/when a second, structurally distinct gate-enforced-duplication mechanism is found.

## Appendix

- Searches/commands used: `sed -n` reads of `lint-agent-contracts.sh` (header, fragment-path
  variable block, Check F exclusion array) and `lint-postflight-boundary.sh` (header, heading
  regex, violation reporting); `grep -n`/`grep -rl` over `context/` and `docs/` for
  `gate-enforced`/`verbatim`/`lint-agent-contracts`/`lint-postflight-boundary` references; a
  Python read of `index-entries.json`'s 171-entry array to confirm the `context/`-only indexing
  scope and extract the two sibling entries' exact shape; live baseline runs of both lints for
  the VERIFY (b) before/after reference.
- References: `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`,
  `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`,
  `agent-system/extensions/core/context/standards/task-reference-exemptions.md`,
  `agent-system/extensions/core/context/standards/record-version-exemptions.md`,
  `agent-system/extensions/core/context/standards/documentation-standards.md`,
  `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`,
  `agent-system/extensions/core/index-entries.json`.
