# Research Report: Task #359

**Task**: 359 - Close lint curated array coverage gaps
**Started**: 2026-10-17T09:00:00Z
**Completed**: 2026-10-17T09:45:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (source store, 1171 lines)
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` (950 lines)
- `agent-system/extensions/core/context/contracts/no-task-references-bullet.md`
- `agent-system/extensions/core/context/contracts/plan-status-ownership.md`
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
- Direct read of `books/agents/books-implementation-agent.md`, `books/agents/books-implementation-hard-agent.md`, and all 23 `*research*agent.md` files named in the dispatch
- A live run of `lint-agent-contracts.sh --verbose` against the current source store
**Artifacts**:
- This report: `specs/359_close_lint_curated_array_coverage_gaps/reports/01_lint-array-coverage-gaps.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Gap 1 confirmed, with the prior record's framing corrected.** Both books files are absent
  from Check C's and Check G's curated arrays, exactly as measured. But `books-implementation-
  agent.md` is NOT a pure omission: it already carries both bullets' correct wording, miswrapped
  across physical lines (Check C item) and additionally misplaced in the **MUST DO** list with
  extraneous backticks (Check G item). `books-implementation-hard-agent.md` has a genuine
  abbreviated paraphrase for Check C and a genuinely absent Check G bullet. Registering both
  files without first normalizing text would turn the lint red, confirming the dispatch's own
  warning.
- **Gap 2 resolved by measurement, not glob: 11 of 23 research agents are genuinely exposed.**
  `books-research-agent.md`, `books-research-hard-agent.md`, `cslib-research-agent.md`,
  `cslib-research-hard-agent.md`, `nix-research-agent.md`, `neovim-research-agent.md`,
  `web-research-agent.md`, `python-research-agent.md`, `rust-research-agent.md`,
  `z3-research-agent.md`, and `core/agents/general-research-agent.md` each name a concrete local
  build/test invocation (or, for `general-research-agent.md`, carry no tool restriction at all,
  which is a *stronger* exposure than a scoped grant). The other 12 are recorded exclusions with
  per-file reasons: 2 Lean agents already use the separate sanctioned `lake-build-guard.sh`
  mechanism; the remaining 10 (`pr-review-research-agent.md`, `epi-research-agent.md`,
  `deck-research-agent.md`, `latex-research-agent.md`, `slides-research-agent.md`,
  `typst-research-agent.md`, and all four `formal`-family agents) hold a Bash grant that is
  either narrowly non-build-shaped or unrealized boilerplate never exercised anywhere in the
  file's own execution flow.
- **Line-wrap ruling: hold bullets unwrapped by convention, not whitespace-normalize the lint.**
  Check H's own fragment already states this convention explicitly ("each on a single physical
  line"); Check C's and Check G's fragments do not yet say so, which is exactly how the wrap
  slipped through undetected. Recommend adding the identical sentence to both fragments rather
  than teaching the lint to collapse whitespace, which would widen three greps' matching
  semantics for a single historical accident.
- **Curated-array mechanism: keep it, but add a completeness net.** The books gap and the
  deliberate sweep below both confirm the arrays are doing real work a filename glob cannot do
  (several founder/present agents write non-markdown artifacts that stay inside `specs/**` and
  are correctly excluded only by reading each file). The missing piece is not derivation but
  *coverage auditing*: a new check enumerating every `*implementation*agent.md` and
  `*research*agent.md` file and asserting each is in an in-scope array or a reasoned exclusion
  list would have caught both measured gaps immediately.
- **Sweep of Check C and Check G found no further absentees** beyond the two books files (one
  debatable edge case, `literature/agents/literature-agent.md`, is flagged but not recommended
  for inclusion — see Findings).

## Context & Scope

Task 359 closes two measured gaps in `lint-agent-contracts.sh`'s curated path arrays (Check C's
`IN_SCOPE_RELATIVE_PATHS`, Check G's `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS`, and a new research-agent
array for the bounded-wait bullet pair Check H currently restricts to implementation agents), and
rules on whether the curated-array shape itself should survive. Scope is bounded to
`lint-agent-contracts.sh`, its test file, and the three contract fragments
(`no-task-references-bullet.md`, `plan-status-ownership.md`, `bounded-build-waiter.md`); no new
documents, and `general-implementation-agent.md` is explicitly out of scope (canonical source,
reused verbatim).

## Findings

### Gap 1: the two books files, re-derived

A live `--verbose` run of the lint today (before any edit) exits 0 with 0 failures, 13 warnings —
**not** because the books files pass Check C/G, but because they are absent from both arrays
entirely, so the per-file loop never visits them. This confirms the dispatch's framing: the gap is
array membership, not a check failure.

**`books/agents/books-implementation-agent.md` — Check C (no-task-references bullet)**: carries
the canonical wording at lines 320-322, but wrapped across three physical lines:
```
6. Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see
   `.claude/rules/no-task-references-in-deliverables.md`; reference durable anchors (filenames,
   section headings) instead
```
`grep -qF` against the fragment's single-line expected text cannot match a three-line bullet.
Unwrapping this one line is a complete fix for Check C's half of this file.

**`books/agents/books-implementation-agent.md` — Check G (plan-status ownership bullet)**: the
bullet's content is present, but with two independent defects beyond wrapping:
1. It sits in the **MUST DO** numbered list (item 6, lines 305-308) rather than **MUST NOT** —
   semantically backwards, since the sentence is a prohibition ("never by this agent").
2. It wraps `update-plan-status.sh` and `update-task-status.sh` in backticks; the fragment's
   canonical text and all 11 other carrying files (`cslib-implementation-agent.md`,
   `cslib-implementation-hard-agent.md`, `founder-implement-agent.md`, `latex-implementation-
   agent.md`, both `lean-implementation-*agent.md` files, `nix-`, `neovim-`, `python-`, `rust-`,
   `typst-`, `web-`, `z3-implementation-agent.md`) spell these two names with no backticks. Even
   after unwrapping, `grep -qF` would still miss on this formatting difference alone.

Both defects must be fixed — unwrap, move to MUST NOT, drop the two backtick pairs — not just the
wrap, to make Check G pass once this file is registered.

**`books/agents/books-implementation-hard-agent.md` — Check C**: item 7 (line 300) is a genuine
abbreviated paraphrase, `Reference task numbers in files outside \`specs/**\``, missing both the
`("task N", "tasks N-M")` parenthetical and the rule cross-reference. Needs full replacement with
the canonical sentence, not a wrap fix.

**`books/agents/books-implementation-hard-agent.md` — Check G**: the bullet is genuinely absent
as any kind of statement — confirmed by a full grep for `update-plan-status`, `Hand-edit`, and
`### Phase` editing language anywhere in the file; none appear. The file does instruct
phase-heading edits ("**A. Mark Phase In Progress** — same Edit-tool mechanics as the base
agent", "**D. Mark Phase Complete** — same Edit-tool mechanics as the base agent", Stage 4), which
is exactly Check G's classification trigger, so it qualifies for in-scope status and needs the
bullet added as a new MUST NOT item (16, after the current 1-15).

The prose-ownership language the dispatch flagged (lines 103-105 and 130-132 of the base agent:
"Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per
phase...") is, on inspection, **already the fragment's own "Clarifying Sentence" text verbatim**
— that part is compliant and needs no change. Only the numbered-list MUST-NOT bullet itself is
missing/misplaced.

An adjacent, pre-existing defect noticed while reading `books-implementation-agent.md`'s MUST NOT
list: item numbering restarts at "9." after item 12 (lines 325-335) rather than continuing to 13.
This is unrelated to either gap but sits in the exact section this task edits; fixing it in the
same pass is zero-risk and avoids compounding a numbering bug this task would otherwise leave
behind in a freshly-touched section.

### Gap 1 sweep: are there further Check C/G absentees?

A full enumeration of all 77 dispatchable agent files (frontmatter-gated: first line `---`, a
`name:` key present) against Check C's 30-entry array and Check G's 14-entry array, cross-checked
against each fragment's own classification rule, found:

- **Check C**: no further absentees. Every candidate outside the current array is either (a) a
  research-only agent (explicitly out of scope per the fragment's own exclusion category), or (b)
  a founder/present "forcing questions" agent (`finance-agent.md`, `financial-analysis-agent.md`,
  `founder-spreadsheet-agent.md`, `budget-agent.md`, `funds-agent.md`, `grant-agent.md`,
  `project-agent.md`, and others) whose XLSX/JSON/markdown outputs are verified, by reading each
  file's own output-path literals, to live entirely under `specs/{NNN}_{SLUG}/` — inside the
  `specs/**` exemption, so correctly excluded — or (c) a pure router/coordinator with no
  deliverable-authoring surface of its own (`code-reviewer-agent.md`: no Write-adjacent output
  path anywhere, matching Check F's own exclusion rationale; `filetypes-router-agent.md`:
  delegates to already-classified sub-agents; `formal-research-agent.md`: routes to
  logic/math/physics-research-agent). By contrast, the four agents already correctly IN scope
  that also produce non-markdown artifacts (`deck-builder-agent.md` → `strategy/{slug}-deck/`,
  `slidev-assembly-agent.md` → `strategy/{slug}-deck/slides.md`, `pptx-assembly-agent.md` →
  `talks/{N}_{slug}/{slug}.pptx`, `meeting-agent.md` → a caller-supplied path) all write outside
  `specs/**`, confirming the array is drawing the line correctly rather than arbitrarily.
  - One genuine edge case, flagged but **not** recommended for action here:
    `literature/agents/literature-agent.md` holds `tools: Bash, Read, Write, Edit` and writes
    markdown summaries into the global `~/Projects/Literature/` corpus — outside this repo
    entirely, hence outside `specs/**` in the literal sense the rule's exemption category names.
    Whether a corpus external to this repository is the kind of "deliverable file" the rule's
    rationale (task-number citations going stale after a vault renumbering) was written for is a
    judgment call distinct in character from every other entry in the array; recorded as a
    follow-up for a human/agent to classify deliberately rather than folded into this task's
    already-measured scope.
- **Check G**: no further absentees. The fragment's own 14-entry enumeration already records a
  predicate sweep with two explicit "confirmed out of scope" findings
  (`epi-implement-agent.md`, `pr-review-implementation-agent.md`, `email-implementation-agent.md`)
  and a count-correction precedent (`founder-implement-agent.md` added after re-sweep). A
  supplementary grep for phase-heading Edit-tool language (`### Phase \{P\}`, `old_string.*###
  Phase`, `Mark [Pp]hase \[(IN PROGRESS|COMPLETED)\]`) across all 77 agent files surfaced exactly
  the 11 of 14 already-registered files that phrase it in a directly-matchable way, plus
  `books-implementation-agent.md` (the known gap) — and nothing else. The 3 registered files this
  loose grep missed (`cslib-implementation-hard-agent.md`, `nix-implementation-agent.md`,
  `web-implementation-agent.md`) were independently confirmed present in the lint's own live PASS
  output, so the grep's negative result elsewhere is corroborating evidence, not the sole basis
  for "no further absentees."

### Gap 2: the research-agent bounded-wait subset, determined by measurement

Per-file classification of all 23 names in the dispatch, based on each file's own `## Allowed
Tools` / tool-grant section and a search for any concrete build/test command actually named
anywhere in the file body (not merely implied by a generic phrase):

**In scope (11) — a concrete local build/test command is named, or Bash is wholly unrestricted**:

| File | Evidence |
|---|---|
| `books/agents/books-research-agent.md` | `Bash - Run \`lake build\`, \`books-tool validate\|check\|levels\`, and the certify driver ... for verification` |
| `books/agents/books-research-hard-agent.md` | same family, live-tree `lake build`/certify invocation |
| `cslib/agents/cslib-research-agent.md` | `Bash - Run \`lake build\` for verification` — no guard/detach language anywhere |
| `cslib/agents/cslib-research-hard-agent.md` | same |
| `nix/agents/nix-research-agent.md` | `Bash - Run verification commands, nix flake check, nixos-rebuild, home-manager build` |
| `nvim/agents/neovim-research-agent.md` | `Bash - Run verification commands, nvim --headless tests` |
| `web/agents/web-research-agent.md` | `Bash - Run verification commands, pnpm build/check`; `Local build first (pnpm check && pnpm build)` |
| `python/agents/python-research-agent.md` | ``pytest -v` - Run tests` named explicitly |
| `rust/agents/rust-research-agent.md` | ``cargo check`, `cargo tree`, `cargo doc --open`` named explicitly |
| `z3/agents/z3-research-agent.md` | ``pytest -k "z3" -v` - Run Z3-related tests` named explicitly |
| `core/agents/general-research-agent.md` | **No `## Allowed Tools` section at all** — Bash is unrestricted, a strictly *wider* exposure than any scoped grant below. Already carries `external-process-wait.md`'s remote-wait discipline (its "Wait Discipline"/"External Process Wait Discipline" section) but neither half of the local bounded-wait bullet pair — the exact partial-coverage shape the dispatch names. |

**Excluded — Lean's separate sanctioned mechanism (2), not instances of the defect**:

- `lean/agents/lean-research-agent.md`, `lean/agents/lean-research-hard-agent.md`: both
  explicitly route their `lake build` through `lake-build-guard.sh`, stating "detached as a
  shell-level background job ... routed through the build guard" — a domain-adapted mechanism
  bounded-build-waiter.md's own "Conforming Examples" section already names as prior art, not a
  gap. Must not receive the generic bullet pair (it would be a second, conflicting instruction).

**Excluded — not genuinely exposed (10), with the distinguishing evidence**:

- `cslib/agents/pr-review-research-agent.md`: Bash scoped only to `gh api` (remote, not local) and
  `python3` for a Zulip client script — no local verification/gate/build/test surface.
- `epidemiology/agents/epi-research-agent.md`: Bash scoped only to "file operations, inspect data
  files, count lines/columns" — no build/test words anywhere.
- `founder/agents/deck-research-agent.md`: Bash scoped only to "Verify file operations, read task
  data" — same shape.
- `latex/agents/latex-research-agent.md`: Bash grant reads only "Run verification commands" with
  zero concrete realization anywhere else in the file (no `latexmk`/`pdflatex`/`make` mention).
- `present/agents/slides-research-agent.md`: explicitly "format-agnostic" by its own overview —
  "Assembly agents (pptx-assembly-agent, slidev-assembly-agent) consume the report in a later
  workflow" — the research stage never builds the deck itself.
- `typst/agents/typst-research-agent.md`: Bash grant reads only "Run verification commands"; its
  one concrete script mention (`chapter-quality-check.sh`) is named only as "what implementation
  will be checked against," i.e. a downstream gate the research agent never itself invokes.
- `formal/agents/formal-research-agent.md`, `formal/agents/logic-research-agent.md`,
  `formal/agents/math-research-agent.md`, `formal/agents/physics-research-agent.md`: all four
  share the identical boilerplate line `Bash - Run verification commands, build scripts, tests`,
  but a full-file grep for `lake build`, `lean`, `cargo`, `pytest`, or any `.sh` invocation found
  zero realizations in any of the four. Each file additionally states its Mathlib-lookup MCP
  tools are "lookup-only... Do not use implementation tools" — these are coordination/lookup
  agents whose Bash grant is unexercised boilerplate, the same shape as latex/slides/typst above,
  not a build-genuinely-invoked agent like the `cslib`/`books` pair they superficially resemble.

11 + 2 + 10 = 23, accounting for every name in the dispatch. None of the 11 in-scope files carry
any existing bounded-wait-adjacent text today (`bounded-build-waiter`/`kill -0`: zero hits across
all 11), so this is a clean propagation, not a partial-coverage repair, for every file except
`general-research-agent.md` (whose one existing half is the remote-wait discipline, not a
collision with the new local-wait bullet pair).

### Line-wrap ruling

Check H's fragment (`bounded-build-waiter.md`, "Copy this exact text" subsection) already states:
"Copy both bullets below, **verbatim and each on a single physical line**." Check C's fragment
(`no-task-references-bullet.md`) and Check G's fragment (`plan-status-ownership.md`) say only
"Copy this exact text ... into the target agent's MUST NOT list," with no single-physical-line
instruction. This asymmetry is the direct cause of the wrap slipping through on `books-
implementation-agent.md`'s Check C bullet undetected by any prior reviewer: the one fragment that
already states the convention has zero wrap incidents among its carrying files; the two that
don't state it have one.

**Ruling: hold bullets unwrapped by convention, stated explicitly in all three fragments; do not
teach the lint to normalize whitespace.** Rationale: whitespace-normalizing `grep -qF` would
require either collapsing each candidate file's relevant region to one line before matching (a
nontrivial text transform touching three independent check functions, each with its own extracted
`expected` string) or switching to a multi-line-aware match (regex with `\s+` joins), either of
which widens matching semantics for every one of Checks C/G/H's existing callers, not just the one
historical wrap. The existing precedent (Check H's fragment already names the convention, and its
11 carrying files have zero wrap incidents) is cheaper, consistent with how the rest of this
generated-copy-plus-lint shape already works, and the two fragments missing the sentence are a
one-line documentation gap, not a design gap.

### Curated-array mechanism: keep, and add a completeness net

The sweep above is itself the strongest evidence for keeping curation: several founder/present
agents write real, non-markdown artifacts (XLSX, JSON) that a naive "writes something other than
a report" heuristic would flag, and only reading each file's own output-path literals (confirming
they resolve inside `specs/{NNN}_{SLUG}/`) correctly excludes them. A filename glob also cannot
distinguish `cslib-research-agent.md` (genuinely runs `lake build`, no guard) from
`lean-research-agent.md` (runs the identical command through a sanctioned, differently-shaped
guard) — both match `*research*agent.md` identically.

What curation does NOT currently have, and what produced both measured gaps, is a **completeness
check**: nothing today asserts that every file matching the relevant shape is accounted for in
*some* list (in-scope, exclusion-with-reason, or not-applicable). Check H's own header comment
already documents the exact reproduce command for this shape
(`find . -name '*implementation*agent.md' | sort`), proving the mechanical net already exists as
a manual audit habit — it was simply never automated or exit-code-gated. Recommend a new check
(next available letter: **M**, since D is reserved/deferred and E-L are taken) that:
1. Enumerates `agent-system/extensions/*/agents/*implementation*agent.md` and asserts each entry
   is in Check G's `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` OR a recorded Check-G exclusion list (the
   fragment's existing 3-file "confirmed out of scope" set, promoted from prose to an array the
   same way `EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS` already works for Check F).
2. Enumerates `agent-system/extensions/*/agents/*research*agent.md` and asserts each entry is in
   the new research bounded-wait in-scope array OR a recorded exclusion list (the 12 files found
   above, each with its reason, structured the same way).
3. For Check C, whose scope is not reducible to one filename glob, apply the same completeness
   net only to the `*implementation*agent.md` subset (a strict subset of Check C's actual scope,
   but the subset the fragment's own rule makes unconditional — "every dispatchable
   implementation agent ... and any future addition" — so a glob-based net is safe there without
   false-failing a legitimately-excluded non-implementation agent).

This directly satisfies the dispatch's ask: "add a check that FAILS when an agent file matching
the shape is in none of in-scope, exclusions, or a recorded rationale."

## Decisions

- Both books files are registered in Check C and Check G, but only after their bullets are
  normalized (unwrapped, backticks removed, moved to MUST NOT, abbreviated text replaced) —
  registering first and fixing text after would transiently redden the lint, which the dispatch
  explicitly warns against.
- The research-agent bounded-wait subset is 11 of 23, not all 23 — determined by a concrete
  per-file command/tool-grant check, not the `*research*agent.md` filename glob. The 2 Lean
  agents keep their existing sanctioned mechanism untouched. The remaining 10 get a recorded
  exclusion with an inline per-file reason (four of them, the `formal` family, share one reason:
  unrealized boilerplate, not a build genuinely invoked anywhere in the file).
- Line-wrap brittleness is resolved by convention (explicit "single physical line" instruction
  added to all three fragments) plus a pinning fixture, not by lint-side whitespace
  normalization.
- The curated-array mechanism stays, with a new completeness-check recommendation (Check M) added
  as the structural fix for "drift goes undetected until measured," rather than replacing
  curation with a glob that the sweep above shows would misclassify real, already-correctly-
  excluded files.
- `literature/agents/literature-agent.md` is flagged as a Check C edge case and explicitly left
  for deliberate follow-up classification, not folded into this task's measured scope.

## Recommendations

1. **`books/agents/books-implementation-agent.md`**: unwrap the Check C MUST NOT bullet (item 6)
   to one physical line; move the Check G bullet out of MUST DO item 6 into a new MUST NOT item,
   dropping the two extraneous backtick pairs around `update-plan-status.sh`/
   `update-task-status.sh` so it matches the fragment's canonical text exactly; renumber the
   trailing MUST NOT items (the pre-existing "9." repeat at line 335 onward) to a single
   continuous sequence while in the same section.
2. **`books/agents/books-implementation-hard-agent.md`**: replace MUST NOT item 7's abbreviated
   paraphrase with the Check C fragment's full canonical sentence; add a new MUST NOT item 16
   carrying Check G's canonical bullet verbatim.
3. Register both files' relative paths in `lint-agent-contracts.sh`'s `IN_SCOPE_RELATIVE_PATHS`
   (Check C) and `OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` (Check G) arrays, and in
   `no-task-references-bullet.md`'s prose enumeration (which currently omits "books" from its
   named extension list) and its "four compliant agents" placement-example list, and in
   `plan-status-ownership.md`'s "In-Scope Enumeration (14 files)" fenced block (→ 16 files).
4. Add the sentence "each on a single physical line" (or equivalent) to `no-task-references-
   bullet.md`'s and `plan-status-ownership.md`'s "Copy this exact text" instructions, mirroring
   `bounded-build-waiter.md`'s existing wording, and add one fixture per fragment to
   `test-lint-agent-contracts.sh` pinning that a correctly-worded-but-wrapped bullet still FAILs
   (proving the convention is enforced, not merely documented).
5. Add a new generated-copy section to `bounded-build-waiter.md` for the research-agent subset
   (mirroring its existing "Classification Rule"/"Item 4 Ruling" structure), recording the
   11-file in-scope array and the 12-file exclusion list with per-file reasons determined above;
   propagate the MUST/MUST NOT bullet pair verbatim into all 11 in-scope research agent files'
   `## Critical Requirements` lists (creating that section where absent).
6. Add a new `BOUNDED_WAIT_RESEARCH_IN_SCOPE_RELATIVE_PATHS` array and a new check (e.g. `check_m_
   bounded_wait_research_contract_bullet`) to `lint-agent-contracts.sh`, structurally identical to
   `check_h_bounded_wait_contract_bullet`, wired into `main()` after Check L.
7. Add the completeness-net check(s) described above (new letter, e.g. `N`) for the
   `*implementation*agent.md` glob against Check G (and, as a subset-only net, Check C) and the
   `*research*agent.md` glob against the new research bounded-wait array.
8. Add the deliberate-removal demonstration the ACCEPTANCE criteria requires as a verification
   step during implementation: temporarily strip the registered bullet from one real file of each
   newly-covered class (one books file for Check C/G, one research agent for the new check),
   confirm the lint FAILs by that file's name, then restore and confirm exit 0 — this is a
   one-shot manual verification during implementation, not a standing fixture.
9. Extend `test-lint-agent-contracts.sh` with fixtures for: the new research bounded-wait check
   (a missing-bullet negative and a near-miss-paraphrase negative, mirroring Check H's existing
   pair), the two line-wrap pinning fixtures from item 4, and assertions that the two real books
   files (once fixed) pass Checks C and G by name in the live-repo smoke section if one exists, or
   via dedicated scratch fixtures otherwise.
10. Run `shellcheck` against the modified lint script per `context/standards/shell-strict-mode.md`
    and `check-task-references.sh` against every changed `agent-system/**` path before redeploy;
    redeploy afterward per `rules/source-store-deploy-boundary.md`.

## Risks & Mitigations

- **Risk**: registering the books files before normalizing their bullet text would make the lint
  exit 1 mid-implementation. **Mitigation**: the plan should sequence text normalization strictly
  before array registration within each check (already reflected in Decisions above).
- **Risk**: the new research-agent check could double-count or conflict with Check K's existing
  whole-corpus antipattern check. **Mitigation**: Check K already covers every dispatchable agent
  (not just the new array) for the *absence of a contradicting instruction*; the new check is
  presence-only, scoped narrowly to the 11-file array — the two are complementary by construction
  the same way Check H and Check K already are for implementation agents.
- **Risk**: the `formal`-family exclusion (4 files, identical boilerplate reason) could look like
  under-scrutiny if a future edit of any one of the four actually wires in a real `lake build` or
  similar. **Mitigation**: record the exclusion reason inline per-file in the new fragment
  section (not just "formal family, see above"), so a future diff touching any one file's Bash
  grant is reviewable against its own recorded justification.
- **Risk**: the `literature-agent.md` edge case, if later decided in-scope, would need the same
  normalize-before-register sequencing as the books files. **Mitigation**: explicitly deferred,
  not silently dropped — recorded in this report for a deliberate follow-up decision.

## Context Extension Recommendations

- **Topic**: curated-array completeness auditing. **Gap**: no existing context file documents
  the "enumerate by filename glob, assert array membership or recorded exclusion" pattern as a
  reusable lint technique, even though Check H's header comment already uses the glob manually
  for re-audits. **Recommendation**: once the new completeness check (recommendation 7 above) is
  implemented, consider a short pattern note (e.g. `context/patterns/curated-array-completeness-
  net.md`) describing the glob-plus-exclusion-list shape so a future fourth curated array (should
  one arise) reuses it by design rather than being discovered as a fifth drift incident.

## Appendix

### Search queries / commands used

- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose` (baseline run)
- `grep -n "Hand-edit the plan METADATA" */agents/*.md` and `grep -n "Reference task numbers" */agents/*.md` (cross-file bullet presence/formatting comparison)
- `find agent-system/extensions -path "*/agents/*.md" -type f` filtered by the frontmatter-gated `is_dispatchable_agent` predicate, diffed against Check C's and Check G's arrays via `comm -23`
- Per-file `## Allowed Tools` / Bash-grant greps across all 23 named research agents, plus a
  full-file grep for concrete build/test command tokens (`lake build`, `pytest`, `cargo`,
  `pnpm`, `nixos-rebuild`, `latexmk`, `.sh` invocations) to distinguish genuine exposure from
  unrealized boilerplate
- `grep -rlE '### Phase \{P\}|old_string.*### Phase|Mark [Pp]hase \[(IN PROGRESS|COMPLETED)\]' */agents/*.md` (supplementary Check G completeness grep)

### Files read in full

- `agent-system/extensions/books/agents/books-implementation-agent.md`
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md`
- `agent-system/extensions/core/context/contracts/no-task-references-bullet.md`
- `agent-system/extensions/core/context/contracts/plan-status-ownership.md`
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
