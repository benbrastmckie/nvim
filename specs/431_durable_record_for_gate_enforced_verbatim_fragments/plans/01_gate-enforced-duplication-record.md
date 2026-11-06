# Implementation Plan: Task #431

- **Task**: 431 - Durable record for gate-enforced verbatim fragments
- **Status**: [NOT STARTED]
- **Effort**: 3.5 hours
- **Dependencies**: None (the declared territory edge onto the systematic script-and-test
  corpus-efficiency record is already discharged: that record is `completed`, so
  `agent-system/extensions/core/scripts/lint/` is no longer claimed by it)
- **Research Inputs**: `specs/431_durable_record_for_gate_enforced_verbatim_fragments/reports/01_gate-enforced-fragment-duplication-record.md`
- **Artifacts**: plans/01_gate-enforced-duplication-record.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The constraint this task exists to make durable — that some markdown duplication in the
agent/skill corpus is deliberate and gate-enforced, so collapsing it changes a gate's finding
set rather than cleaning anything up — **already has a durable, index-registered home**:
`agent-system/extensions/core/context/standards/anchor-pointer-convention.md`, whose section
`## The Two Hard Exclusion Classes` states the exclusion class, states the derivation rule
("Recognize this class by reading the live fragment/predicate set out of the enforcing script at
the time of the collapse, never from a hardcoded list in this document"), and names both known
enforcers. This plan therefore does **not** create a new record. It closes the one component of
the dispatch's SCOPE that is genuinely absent from that record — the DISCOVERY PATH — and
strengthens the three components that are present but thin, in the single home the constraint
already has. Definition of done: a consolidation, dedup, corpus-reduction, or template-extraction
pass reaches the constraint through four independent hooks before it plans; both enforcing gates
produce byte-identical finding sets before and after; the full gate set is green and the deploy
lands clean.

### Research Integration

The research report's mechanics are adopted wholesale and re-verified at plan time:

- `lint-agent-contracts.sh` resolves **six** path variables at lines 141-146 (`STANDARD_FILE`
  plus five `*_FRAGMENT` variables — `FRAGMENT_FILE`, `ARTIFACTS_TEMPLATE_FRAGMENT`,
  `PLAN_STATUS_OWNERSHIP_FRAGMENT`, `BOUNDED_WAIT_FRAGMENT`, `MODIFIED_FILES_FRAGMENT`), one
  more fragment than the originating plan's own count. Confirmed live. This is the standing
  evidence that a hardcoded list rots, and it stays in this plan rather than in the record.
- `lint-postflight-boundary.sh`'s `has_postflight_boundary_section()` (lines ~76-82) greps
  `^## MUST NOT \(Postflight Boundary\)`, with the adjacent comment stating why it is anchored
  to that exact heading and not any `## MUST NOT` heading; a missing heading is a named
  `[VIOLATION]` at lines ~168-176. Confirmed live.
- The report's `index-entries.json`-indexes-only-`context/` finding is adopted and decides
  against any `docs/`-rooted placement.

**One research conclusion is superseded by a plan-time finding.** The report's PLACEMENT
Decision (create a new `context/standards/gate-enforced-fragment-duplication.md`) rested on its
claim that no existing file "states the general principle ... as a standalone, named record",
and it listed `anchor-pointer-convention.md` among the closest hits dismissed as documenting
only "themselves and their own lint usage". That dismissal does not survive reading the file:
its `## The Two Hard Exclusion Classes` section states the class, the behaviour-change
consequence, and the derivation rule in the record's own words, and the file is registered in
`index-entries.json` with a summary that already names the exclusion classes. Creating a second
record would put the derivation rule in two places, where the dispatch's own hard constraint (2)
says it must live in one — and a split rule rots in the dangerous direction exactly as a
hardcoded list would. The chosen placement is therefore the existing record, extended.

### Placement Justification Against Precedent

The dispatch asked for placement to be justified against `task-reference-exemptions.md` and
`record-version-exemptions.md`, the two nearest exemption-taxonomy precedents. Those two are
genuine precedents for *shape* (a principle paired with an exemption taxonomy naming one
mechanical source of truth), and the chosen home matches that shape. But there is a nearer
precedent for *placement*: the constraint's own existing home. Both sibling records are single,
undivided homes for their constraint — neither has a second copy anywhere in the corpus, and
each names exactly one mechanical source of truth. Honouring that precedent means extending the
one existing home, not minting a second. The `docs/reference/standards/agent-frontmatter-standard.md`
candidate is rejected on the research report's own grounds (unreachable through the context
index, which carries zero `docs/`-prefixed paths). The lint-header-pointer candidate is adopted
as a discovery hook (Phase 3), which is how the dispatch framed it, not as the record's home.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; `specs/ROADMAP.md` was not consulted and is not
modified.

## Goals & Non-Goals

**Goals**:
- Extend the existing exclusion-class record so it governs any duplication-removing change, not
  only anchor-pointer collapse-candidate selection, and so it carries the behaviour-change
  framing, the per-gate worked-example detail, and an explicit discovery path.
- Keep the derivation rule as a rule, with a concrete re-derivation procedure a reader can
  follow to reproduce the current exclusion set from the enforcing scripts themselves.
- Give the record four independent discovery hooks, each reaching a different reader: index
  keywords, the planning-decomposition surface, the documentation-standards surface, and each
  enforcing lint's own header.
- Prove both enforcing gates' finding sets are unchanged, by before/after diff against a
  freshly deployed tree.

**Non-Goals**:
- Creating a new context file. The two candidate paths already sitting in this task's declared
  `file_scope` (`context/standards/gate-enforced-duplication.md`,
  `context/standards/gate-enforced-fragment-duplication.md`) are deliberately left unused; a
  declared-but-untouched path is descriptive, not an obligation.
- Changing what either gate checks, or any fragment's text. A moved finding set means scope was
  exceeded.
- Hardcoding the exclusion set, the fragment-path list, or a fixed count of enforcing gates into
  the record.
- Generalizing the class beyond gate-enforced markdown (e.g. golden-file or fixture duplication
  enforced by a test). Not currently observed; the derivation rule covers its arrival.
- Editing `docs/reference/standards/agent-frontmatter-standard.md`, also declared in
  `file_scope` and also deliberately untouched.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A pointer elsewhere cites the section heading verbatim, so renaming it breaks a reference | M | L | Verified at plan time: the string `Two Hard Exclusion Classes` occurs in exactly one place in `agent-system/**` — the heading itself. Phase 2 re-runs that grep immediately before renaming and abandons the rename if a citation has appeared. |
| `lint-postflight-boundary.sh`'s no-argument default scans the **deployed** tree, so a naive before/after diff is confounded by deploy staleness (this dispatch's own freshness note flags `core`/`lean` as stale) | H | H | Phase 1 redeploys FIRST, then captures the baseline, so both sides of the diff observe a fresh tree. Gate 9 is also invoked through `verify-deploy.sh` (which runs the deployed copy from `$TARGET`) rather than by hand, so the before and after invocations are identical by construction. |
| A comment-only edit to a lint header is mistaken for, or accidentally becomes, a change to what the gate checks | H | L | Neither lint has a `usage()` that `sed`-extracts its header (verified: no `usage()` function in either file), so a header comment is inert. Phase 3's own verification diffs gate 6 and gate 9 output against the Phase 1 baseline and requires byte-identical finding sets. |
| An implementer inlines the current six-variable list "for concreteness", reintroducing the staleness the dispatch forbids | H | M | The six variables are recorded in THIS plan, never in the record. Phase 2's task list states the prohibition inline and Phase 6 verifies by grep that no fragment path appears in the record. |
| The measured scale figure (~3,997 of 16,851 lines) has no durable anchor: its inventory lives at a task-scoped `specs/**` path that a deliverable under `agent-system/**` may not cite | M | H | Phase 2 states the magnitude qualitatively (order of a quarter of the apparent reduction opportunity) and names how to re-measure it, rather than citing an unverifiable precise number or a task-scoped path. |
| `__WHOLE_TREE__` in Phases 1 and 6 exact-matches a concurrent sibling's identical claim and serializes this task behind it | L | M | This is the designed behaviour of the whole-tree-claim admission dimension, not a defect. The claim is declared honestly; serialization is the correct outcome, and no real wide path is substituted to evade it. |
| `index-entries.json` is claimed by several other active records, and a concurrent append collides | M | L | Phase 5 re-reads the file immediately before editing, appends/edits only this record's own three entries, and stages only that file's own hunks. `generate-context-line-counts.sh --write` touches `line_count` only, leaving every other field alone. |
| A pointer added to an index-`load_when`-eager file inflates the orchestrator eager-context budget (gate 20) | L | L | `measure-eager-context.sh` measures CLAUDE.md plus path-glob-matched `rules/*.md`, not index `load_when` files, so neither pointer host is in that budget. Each pointer is capped at one line regardless, and gate 20 runs in Phase 6's full set. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 2, 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Establish a Fresh-Tree Gate Baseline [NOT STARTED]

**Goal**: Capture the pre-change finding sets of both enforcing gates against a freshly
deployed tree, so the Phase 6 before/after diff measures this task's edits and nothing else.

**Tasks**:
- [ ] Resolve `source_dir` from `/home/benjamin/.config/nvim/.claude-extensions.json` and
      confirm it resolves to the `agent-system/extensions` source store; confirm the repository
      root (the directory holding `.claude-extensions.json`) is simultaneously a deploy consumer
      (it has a `.claude/` tree) — this is what makes it a valid `TARGET` for the gate subsets
      used in later phases.
- [ ] Redeploy the tree: `bash agent-system/extensions/core/scripts/deploy-headless.sh` (whole-tree
      regeneration — this is why `__WHOLE_TREE__` is declared below). Confirm it exits 0.
- [ ] Capture gate 6 and gate 9 baseline output to the scratchpad:
      `bash .claude/scripts/verify-deploy.sh --only-gate 6,9 /home/benjamin/.config/nvim`
      redirected to a baseline file under the session scratchpad directory. Record its exit
      status alongside the output.
- [ ] Separately capture the raw verbose output of each enforcing lint, using the exact
      invocation shapes `verify-deploy.sh` itself uses, so the diff can be taken at lint
      granularity as well as gate granularity:
      `REPO_ROOT=/home/benjamin/.config/nvim bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
      and `bash .claude/scripts/lint/lint-postflight-boundary.sh --verbose`.
- [ ] Confirm each captured baseline file is non-empty and records a definite verdict (a
      pass/fail count, not a silent zero-files-checked result). A zero-files-checked
      postflight-boundary baseline is a signal the redeploy did not land and must be resolved
      here, not carried into the diff.
- [ ] Commit nothing in this phase (no tracked file changes).

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The phase's only mutation is a regeneration of the gitignored deployed
tree, and the covering check is the very invocation the phase exists to run —
`bash .claude/scripts/verify-deploy.sh --only-gate 6,9 /home/benjamin/.config/nvim` — whose
non-empty, definite output is the phase's own deliverable.

**Scope Hypothesis**: This phase assumes the deployed tree is currently stale for `core` (per
this dispatch's freshness note) and that a redeploy therefore changes the gate 9 baseline.
Confirm by comparing the postflight-boundary lint's files-checked count before and after the
redeploy; if it was already fresh the counts match and nothing is lost.

**Files to modify**:
- `__WHOLE_TREE__` - whole-tree regeneration via `deploy-headless.sh`; no tracked source file is
  edited in this phase

**Verification**:
- `deploy-headless.sh` exits 0.
- `bash .claude/scripts/verify-deploy.sh --only-gate 6,9 /home/benjamin/.config/nvim` exits 0;
  its exit status is recorded alongside the captured output, since the baseline is only a valid
  comparison point if the gates were passing when it was taken.
- A baseline capture file exists for gate 6, gate 9, and each lint's raw verbose run, each
  non-empty, each carrying a definite verdict line, and each with its invocation's exit status
  recorded.
- The postflight-boundary baseline reports a non-zero files-checked count.

---

### Phase 2: Strengthen the Exclusion-Class Record in Its Existing Home [NOT STARTED]

**Goal**: Extend `context/standards/anchor-pointer-convention.md`'s exclusion-class section so it
governs any duplication-removing change, carries the behaviour-change framing and per-gate
worked-example detail, states the derivation rule as a followable procedure, and carries an
explicit discovery-path section.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/standards/anchor-pointer-convention.md` in
      full immediately before editing (a sibling record claims
      `agent-system/extensions/core/context/` as a directory scope this cycle).
- [ ] Re-run `grep -rn "Two Hard Exclusion Classes" agent-system/` and confirm the only hit is
      the heading itself. If any pointer now cites it, skip the rename in the next task and keep
      the current heading text.
- [ ] Rename the section heading so it no longer fixes the class count and so it reads as a
      standalone constraint rather than a step in collapse-candidate selection — e.g.
      `## Hard Exclusion Classes: Duplication That Must Not Be Collapsed`. The count must not be
      baked into the heading: the class set grows when a new enforcer appears.
- [ ] Broaden the section's own opening sentence so it applies to **any** change that removes or
      templates duplicated markdown — consolidation, corpus reduction, dedup, template
      extraction, a pointer collapse — not only to anchor-pointer collapse-candidate selection.
      State the consequence in the gate's terms: the gate reads the file's own text at runtime,
      so collapsing, renaming, merging, or templating that text changes the gate's finding set.
      That is a behaviour change to the gate, not a cleanup, and it will present as a passing
      consolidation followed by a failing or silently-narrowed gate.
- [ ] State the magnitude qualitatively, as motivation for why the class must be checked before
      a pass starts rather than discovered by a broken gate: a substantial minority — on the
      order of a quarter — of the apparently removable duplicated markdown in this corpus falls
      into it. Name how to re-measure it (enumerate the enforcing predicates by the derivation
      rule below, then count the lines those predicates pin) rather than carrying a precise
      figure. **Do not cite a `specs/**` path or a task number**: this file is a deliverable
      under `agent-system/**`.
- [ ] Restate the derivation rule as the load-bearing part, with a procedure a reader can
      execute: enumerate the enforcing scripts under `scripts/lint/`; for each, read its own
      path-variable declarations (the `*_FRAGMENT`-style variables resolved near the top of the
      file) and its own literal-text predicates (the `grep -qE` assertions inside its check
      functions); the exclusion set is whatever those currently resolve to, at the time of the
      pass. State explicitly that this record carries no path list and no gate count, that the
      worked examples below are illustrations of the class rather than its definition, and that
      the class grows by a future author re-deriving a new enforcer from its own source and
      adding another illustration — never by extending a canonical list here. Give the reason:
      a copied list rots in the dangerous direction, asserting a fragment is safe to collapse
      after the enforcer began reading a different one.
- [ ] Expand the two worked examples so each names its gate by filename and says what it
      enforces, without reproducing the enforced text or the resolved paths:
      `lint-agent-contracts.sh` reads an expected bullet or fenced JSON template out of a
      fragment file at runtime and FAILs any in-scope agent contract whose own file does not
      carry a verbatim copy — its header states the rationale, that the fragment stay
      load-bearing rather than decorative; `lint-postflight-boundary.sh` asserts one literal
      section heading via a `grep -qE` anchored to that exact heading text and records a missing
      one as a named violation — its own adjacent comment states why it is anchored to that
      heading and not to any `## MUST NOT` heading, since a skill may legitimately carry an
      unrelated MUST NOT section.
- [ ] Add a short contrast note distinguishing this class from the opposite-polarity mechanism
      the same file already documents under `## The Regression Lint`: that lint forbids
      *reintroducing* text into a file already collapsed, driven by a permanent registry; the
      exclusion class here forbids *removing* text a gate reads. Both are gate-managed
      duplication, in opposite directions, and a reader must not conflate them. Keep this to a
      few lines — it is a disambiguation, not a third class.
- [ ] Add a `## Discovery Path` section naming, as an obligation on the reader rather than a
      description of plumbing, the four hooks by which a duplication-removing pass is expected
      to reach this record before it plans: the context index entry (searchable by keyword
      without knowing the filename); the task-decomposition workflow's consolidation pattern
      (reached at planning time); the documentation-standards record's related-standards list
      (reached by `markdown`-typed work); and each enforcing lint's own header pointer (reached
      by anyone reading the gate before touching a fragment). State the obligation plainly: a
      pass that has not read this section has not established which of its candidates are
      load-bearing, and its measured reduction opportunity is therefore unverified.
- [ ] Re-read the finished section and confirm: no fragment path, no variable name beyond the
      generic `*_FRAGMENT` shape description, no gate count, no task number, no
      draft-history or supersession language ("previously", "no longer", "formerly", "v1"), and
      no `specs/**` citation.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: The edit is confined to one markdown file with no executable surface, so
`suite_selection_select` returns `__FULL_SWEEP__` and no shell suite covers it; the honest
covering check is the source-store markdown gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
together with the `prose` row's diff read-through.

**Scope Hypothesis**: This phase asserts that exactly one file needs editing and that the
section heading is cited nowhere else. Confirm by the `grep -rn "Two Hard Exclusion Classes"`
re-run in the task list above, and by `grep -rn "anchor-pointer-convention" agent-system/`, whose
hits at plan time are the index entry, `verify-deploy.sh`'s gate 9 comment, and three lines in
`lint-anchor-pointer-collapse.sh` — all path references, none a heading citation.

**Files to modify**:
- `agent-system/extensions/core/context/standards/anchor-pointer-convention.md` - rename the
  exclusion-class heading, broaden and deepen that section, add the contrast note and a new
  `## Discovery Path` section

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no new findings (gate 3 and gate 4 must each run, not SKIP; a SKIP means the `TARGET`
  was wrong).
- `grep -c` confirms zero occurrences in the edited file of: any `context/contracts/` or
  `context/patterns/` fragment path, `task `, and each of `previously`/`no longer`/`formerly`.
- A reader following the derivation procedure in the record, with no other input, reproduces the
  current exclusion set from the two enforcing scripts — exercised explicitly: follow the written
  procedure and check the result against this plan's own Research Integration list.
- Diff read-through confirms every changed hunk lies inside prose.

---

### Phase 3: Pointer Hooks in Each Enforcing Lint's Header [NOT STARTED]

**Goal**: Add one terse comment line to each enforcing lint's header pointing at the record, so
anyone reading the gate before touching a fragment sees the constraint without searching the
index.

**Tasks**:
- [ ] Re-derive the current enforcer set rather than trusting this plan's list: scan
      `agent-system/extensions/core/scripts/lint/` for scripts that read expected text out of a
      markdown file at runtime or assert a literal markdown heading. If the scan finds an
      enforcer beyond the two named here, add a pointer to it as well and note the finding in
      the issue log; if it finds fewer, resolve the discrepancy before editing.
- [ ] Re-read each target lint immediately before editing (a sibling record is editing other
      files in `scripts/lint/` this cycle).
- [ ] In `lint-agent-contracts.sh`, add one comment line in the existing header block, adjacent
      to the Check C/F/G text that already explains the read-from-fragment mechanism, naming
      `context/standards/anchor-pointer-convention.md` and its exclusion-class section as the
      record that governs collapsing or templating any fragment this script reads.
- [ ] In `lint-postflight-boundary.sh`, add one comment line adjacent to
      `has_postflight_boundary_section()`'s existing rationale comment, naming the same record
      and section.
- [ ] Confirm neither edit touches a non-comment line: both files are shell scripts, and the
      added lines must begin with `#` and sit inside an existing comment block.
- [ ] Confirm by inspection that neither script has a `usage()` that extracts its header via
      `sed` (verified absent at plan time), so the added comments cannot reach stdout.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: Both edits are comment-only lines inside two shell scripts, and the
covering check runs those exact scripts plus the shell linter over them:
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --only-gate 6,9,22 /home/benjamin/.config/nvim`.

**Scope Hypothesis**: This phase asserts the enforcer set is exactly two scripts. Confirm by the
`scripts/lint/` re-derivation scan in the first task above, not by this plan's list — the
derivation rule applies to this plan as much as to a future reader.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - one header comment line
  pointing at the record; no check logic touched
- `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` - one comment line
  beside the heading predicate's existing rationale; no check logic touched

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --only-gate 6,9,22 /home/benjamin/.config/nvim` passes,
  with gate 6 and gate 9 finding sets identical to the Phase 1 baseline (diff, not eyeball).
- `git diff` on both files shows only added lines beginning with `#`.
- Gate 22 (shellcheck) reports no new findings for either script.

---

### Phase 4: Pointer Hooks on the Planning and Documentation Surfaces [NOT STARTED]

**Goal**: Reach a duplication-removing pass at the two moments it decides what to do — when its
phases are being planned, and when it is treated as documentation work — each via one line.

**Tasks**:
- [ ] Re-read both target files immediately before editing.
- [ ] In `context/workflows/task-breakdown.md`, add a short `### Consolidation / Deduplication
      Pattern` entry under the existing `## Common Patterns` heading, matching the shape and
      length of its three sibling patterns (a numbered list of roughly six steps). Its **first**
      step must be reading `context/standards/anchor-pointer-convention.md`'s exclusion-class
      section to separate load-bearing duplication from collapsible duplication, before any
      candidate enumeration; later steps carry the ordinary shape (enumerate candidates, collapse
      in tranches, verify the gate set unmoved, record the claim-retention ledger the record
      already requires).
- [ ] In `context/standards/documentation-standards.md`, add one bullet to the existing
      `## Related Standards` list pointing at `anchor-pointer-convention.md`, described by what
      it governs (collapsed-block shape and the duplication that must not be collapsed), in the
      same `path - description` shape the neighbouring bullets use.
- [ ] Keep each addition minimal: one bullet, and one pattern entry no longer than its siblings.
      Neither file gains a restatement of the record's content — both gain a pointer to it.
- [ ] Confirm neither addition introduces a task number, a `specs/**` citation, or
      draft-history language.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: Both edits are markdown-only with no executable surface, so no shell
suite covers them (`__FULL_SWEEP__`); the honest covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
plus the `prose` row's diff read-through.

**Scope Hypothesis**: This phase asserts these two files are the right pointer hosts because
`documentation-standards.md` is index-loaded for `task_type: markdown` and
`task-breakdown.md` is index-loaded for `planner-agent`. Confirm by re-reading both entries'
`load_when` blocks in `index-entries.json` before editing; if either binding has changed, pick
the file that is actually loaded on the corresponding surface and record the substitution.

**Files to modify**:
- `agent-system/extensions/core/context/workflows/task-breakdown.md` - one new
  `### Consolidation / Deduplication Pattern` entry under `## Common Patterns`
- `agent-system/extensions/core/context/standards/documentation-standards.md` - one bullet under
  `## Related Standards`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no new findings, with both gates running rather than skipping.
- Each file's addition is one bullet / one sibling-sized pattern entry, confirmed by `git diff`
  line count.
- Diff read-through confirms every changed hunk lies inside prose.

---

### Phase 5: Context-Index Registration and Keyword Discoverability [NOT STARTED]

**Goal**: Make the record findable through the context index by the terms a consolidation pass
would actually search, and keep every touched entry's `line_count` accurate.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/index-entries.json` immediately before editing; it is
      claimed by several other active records and a concurrent append is possible.
- [ ] Update the `standards/anchor-pointer-convention.md` entry's `summary` so it names what the
      record now carries — the collapsed-block pointer shape, the duplication that must not be
      collapsed, the derivation rule, the claim-retention ledger, and the discovery path — and
      so it no longer fixes a class count.
- [ ] Extend that entry's `keywords` with the terms a duplication-removing pass would search,
      at minimum: `gate-enforced`, `verbatim-duplication`, `exclusion-class`, `derivation-rule`,
      `consolidation`, `deduplication`, `template-extraction`. Keep the existing keywords.
- [ ] Leave `load_when` empty and `on_demand: true` unchanged: this is on-demand reference
      material, matching both sibling exemption-taxonomy entries. Note that an empty `load_when`
      means `context-reachability.sh`'s index style does not count this file as reachable — the
      filename pointers added in Phases 3 and 4 are what make it reachable by that probe's
      filename style, which is a further reason those phases are part of the deliverable rather
      than optional polish.
- [ ] Do not add a `description` or `tags` key (both are schema-forbidden), keep `domain` at
      `core`, and keep `path`, `subdomain`, `summary`, and `line_count` all present — these are
      doc-lint Rule T's required keys.
- [ ] Refresh `line_count` for every entry whose file this task changed
      (`standards/anchor-pointer-convention.md`, `standards/documentation-standards.md`,
      `workflows/task-breakdown.md`) by running
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`, which
      touches `line_count` and nothing else, then `--check` to confirm zero drift.
- [ ] Stage only this file's own hunks; never a directory or glob pathspec.

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: local

**Tier Justification**: The edit is confined to one JSON data file whose schema and
`line_count` accuracy are owned by doc-lint Rules T and R, and the covering checks are
`bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` plus
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim`.

**Scope Hypothesis**: This phase asserts exactly three index entries need a `line_count`
refresh. Confirm with `generate-context-line-counts.sh --check` before and after: the before-run
should name exactly the entries whose files this task edited, and the after-run should name none.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - updated summary and keywords for the
  `standards/anchor-pointer-convention.md` entry; refreshed `line_count` for the three entries
  whose files this task changed

**Verification**:
- `generate-context-line-counts.sh --check` reports zero drift.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3 /home/benjamin/.config/nvim`
  passes with gate 3 running (Rules R and T both clean).
- `jq` confirms the edited entry still carries `path`, `domain`, `subdomain`, `summary`,
  `line_count`, carries no `description` or `tags` key, and has a `load_when` whose keys are
  drawn only from `agents`/`commands`/`task_types`/`always`.
- `jq` confirms the entries array length grew by zero (this task adds no new file) and that no
  other entry's fields changed.

---

### Phase 6: Redeploy, Full Gate Set, and Finding-Set Diff [NOT STARTED]

**Goal**: Prove both enforcing gates' finding sets are unchanged, the record is resolvable
through the context index, the discovery path works end to end, and the full gate set is green
on a freshly deployed tree.

**Tasks**:
- [ ] Redeploy: `bash agent-system/extensions/core/scripts/deploy-headless.sh`; confirm exit 0.
- [ ] Re-capture gate 6 and gate 9 output with the identical Phase 1 invocation
      (`bash .claude/scripts/verify-deploy.sh --only-gate 6,9 /home/benjamin/.config/nvim`) and
      `diff` it against the Phase 1 baseline. Any difference in the finding set — a new finding,
      a removed finding, or a changed count — means scope was exceeded and must be resolved
      before proceeding, not explained away.
- [ ] Re-capture each lint's raw verbose output with the identical Phase 1 invocations and diff
      those too, so the comparison holds at lint granularity as well as gate granularity.
- [ ] Run the full gate set: `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`.
      Require green. Treat a failure in a file outside this task's own `Files to modify` lists as
      possibly a concurrent sibling's in-flight edit: check `git log` and the working tree before
      attributing it to this task.
- [ ] Confirm index resolvability concretely, not by assertion: from the deployed tree, search
      the merged index for each new keyword and confirm the record's entry comes back; confirm
      the entry's `path` resolves to a file that exists in both the source store and the deployed
      tree.
- [ ] Walk the discovery path end to end as a reader would, once per hook: from
      `task-breakdown.md`'s new pattern entry; from `documentation-standards.md`'s new bullet;
      from each lint header's new comment; and from an index keyword search. Each must land on
      the record's exclusion-class section.
- [ ] Re-confirm the hard constraints by grep over the final diff: no fragment path, variable
      name, or gate count added to the record; no fragment's text changed; no check logic
      changed in either lint.
- [ ] Record the phase's issue-log entries as they arise (including a `win` entry if the
      existing-record finding saved the duplicate-record work it did), per this dispatch's Issue
      Log section.

**Timing**: 0.5 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - whole-tree regeneration via `deploy-headless.sh`; no tracked source file is
  edited in this phase

**Verification**:
- The complete gate set — `bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`,
  all gates, no `--only-gate` and no `--skip-slow` — runs and is green.
- `bash .claude/scripts/verify-deploy.sh --only-gate 6,9 /home/benjamin/.config/nvim` exits 0,
  and its output `diff`s clean against the Phase 1 baseline apart from timing or path-prefix
  noise; the exit status is checked in its own right, never inferred from the diff being empty.
- Each lint's sanctioned entry point —
  `REPO_ROOT=/home/benjamin/.config/nvim bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose`
  and `bash .claude/scripts/lint/lint-postflight-boundary.sh --verbose` — exits 0, and its raw
  verbose output `diff`s clean against its Phase 1 baseline.
- An index keyword search for each newly added keyword returns the record's entry, and that
  entry's `path` resolves in both trees.
- All four discovery hooks are walked and each lands on the record's exclusion-class section.
- `deploy-headless.sh` exits 0 and the deploy-freshness check reports no stale extension.

---

## Testing & Validation

- [ ] Both enforcing gates produce byte-identical finding sets before and after, measured against
      a freshly deployed tree on both sides (dispatch VERIFY (b)).
- [ ] A reader can follow the record's derivation procedure, with no other input, and reproduce
      the current exclusion set from the enforcing scripts themselves (dispatch VERIFY (a)).
- [ ] The record carries no fragment path, no variable name, and no gate count (dispatch hard
      constraint 2).
- [ ] The record is resolvable through the context index, by keyword, without knowing its
      filename (dispatch VERIFY (c), REGISTRATION).
- [ ] All four discovery hooks land on the record (dispatch SCOPE 4).
- [ ] The full gate set is green and the deploy lands clean (dispatch VERIFY (d)).
- [ ] No file under `agent-system/**` touched by this task carries a task number, a `specs/**`
      citation, or draft-history language.

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/anchor-pointer-convention.md` - the extended
  exclusion-class record, with the derivation rule, worked examples, contrast note, and
  `## Discovery Path` section
- `agent-system/extensions/core/context/workflows/task-breakdown.md` - consolidation/dedup
  pattern entry pointing at the record
- `agent-system/extensions/core/context/standards/documentation-standards.md` - related-standards
  pointer
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - header pointer comment
- `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` - header pointer comment
- `agent-system/extensions/core/index-entries.json` - updated summary/keywords and refreshed
  `line_count` values
- A regenerated deployed `.claude/` tree (gitignored; not a committed artifact)
- `specs/431_durable_record_for_gate_enforced_verbatim_fragments/summaries/01_*-summary.md` at
  completion

**No new file is created.** The two new-file candidate paths and
`docs/reference/standards/agent-frontmatter-standard.md` remain in this task's declared
`file_scope` and are deliberately untouched.

## Rollback/Contingency

Every phase's edits are additive and confined to the files that phase lists, and each phase
commits on its own. Reverting any single phase is `git revert` of that phase's commit, or a
targeted re-edit; no phase depends on a destructive operation.

If a finding-set diff in Phase 3 or Phase 6 is non-empty, the correct response is to narrow the
offending edit until the diff is empty — not to accept the moved finding set and not to adjust
the gate. The dispatch's hard constraint is explicit: a moved finding set means scope was
exceeded.

If an unexpected failure requires discarding uncommitted work, that is a genuine rollback: take
a snapshot first per `context/contracts/recovery.md`'s rollback rung (which specifies the
invocation shape, including its out-of-scope override flag) and only then run the destructive
command. An ordinary defensive checkpoint before a risky edit uses
`bash .claude/scripts/git-snapshot.sh 431 --no-revert`, which is durable without reverting the
working tree.
