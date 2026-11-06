# Research Report: Task #495

**Task**: 495 - Formal research agents report section conformance
**Started**: 2026-11-06T00:00:00Z
**Completed**: 2026-11-06T00:40:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/formal/agents/{formal,logic,math,physics}-research-agent.md` (source store, read directly)
- `agent-system/extensions/core/agents/general-research-agent.md` (canonical "Copy source")
- `agent-system/extensions/core/scripts/validate-artifact.sh` (the validator itself, run directly against extracted fixtures and skeletons, not read by eye)
- `agent-system/extensions/core/context/formats/report-format.md`, `summary-format.md`
- `agent-system/extensions/core/scripts/skill-base.sh` (`skill_validate_task_artifacts` path-convention sweep)
- All other extensions' `agents/*.md` under `agent-system/extensions/*/agents/` (mechanical sweep)
- `~/Projects/BimodalLogic/specs/878_.../issues.jsonl` and its report (the production failure, cross-repo read-only reference)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- The diagnosis in abandoned project 166 is correct and re-confirmed mechanically here: the four formal-extension research agents' report skeletons are **not currently invalid** (all four pass `validate-artifact.sh` as literally written), but all four carry **zero** copy of the verbatim required-heading contract, the `^##+ {section}` regex statement, or either named near-miss that project 166 added only to `general-research-agent.md`.
- A fixture reproducing the exact BimodalLogic failure (`## Context Extension Recommendations` present, no `## Recommendations` anywhere) fails `validate-artifact.sh` with precisely the reported error; the formal agents' current nested `### Recommendations` shape, and a promoted top-level `## Recommendations` shape, both pass.
- Recommended ruling: (1) move the verbatim contract into `context/formats/report-format.md` (the actual standard every report's own `**Standards**:` metadata already cites) as the single referenceable home, with `general-research-agent.md` and the four formal agents converted to pointers rather than copies; (2) promote `### Recommendations` to top-level `## Recommendations` in the four formal skeletons — this is a strict structural improvement, not a cost, since it brings formal's shape into alignment with `general-research-agent.md`'s own canonical layout; (3) add a cheap grep-based self-check to the shared contract text rather than a second, redundant `validate-artifact.sh` invocation; (4) the validator was deliberately left unchanged.
- The sweep required by scope item (4) found conformance gaps well beyond the four formal agents and beyond the typst/lean "obvious candidates" the dispatch named — see Findings for the full enumeration. These are explicitly OUT of this record's file_scope and are recommended as separate, later records.

## Context & Scope

This is a research-only dispatch; no files were edited. The task asks this record to decide and
record ONE coherent rule for carrying the required-report-heading contract (established by
abandoned project 166) into the formal extension's four research agents, and to complete the
cross-extension sweep project 166 scoped but never ran. The four hard constraints from the
dispatch bound the investigation: do not relax `validate-artifact.sh`'s matching; keep
`## Context Extension Recommendations` as a distinct section, never a substitute; pre-existing
non-conforming artifacts are out of scope; and any remedy reaching core scripts is pre-authorized
by this record's own description, but a remedy reaching OTHER extensions' agents requires
widening file_scope at plan time (not done here).

All measurements below were done by running the real `validate-artifact.sh` (or an exact-regex,
exact-array Python re-implementation of its single check loop) against extracted file content —
never by reading headings and judging by eye, per the dispatch's explicit instruction.

## Findings

### Codebase Patterns

**The validator's exact contract** (`agent-system/extensions/core/scripts/validate-artifact.sh`):
```
REPORT_SECTIONS=("Executive Summary" "Context & Scope" "Findings" "Decisions" "Recommendations")
SUMMARY_SECTIONS=("Overview" "What Changed" "Decisions" "Impacts" "Follow-ups" "References")
```
checked per-section via `grep -qE "^##+ ${section}"` (any heading depth, exact text after the
`##+ ` prefix). This confirms project 166's finding: the regex is any-depth, so a third-level
`### Recommendations` legitimately satisfies the check — the skeleton is not itself invalid.

**Where the contract currently lives**: only `general-research-agent.md` (core) carries the
verbatim statement of the five headings, the regex, the exact-text warning, and both named
near-misses (`## Recommended Next Steps`, `## Context Extension Recommendations`), added by
project 166's agent-side remedy. Critically, **`context/formats/report-format.md` itself —
the file every single report's own `**Standards**:` metadata line cites as its authority —
was never updated**. Its "## Structure" section still only has plain numbered prose
("6. **Recommendations** – prioritized list...") with no regex, no exact-text warning, and no
named near-misses. This means the standard document agents are told to comply with does not
itself carry the enforcement detail; only one consumer of that standard (`general-research-agent.md`)
happens to restate it. That is the deeper reason the gap was easy to leave half-applied: the fix
landed in a consumer, not in the standard.

**The four formal agents, measured directly**: each of `formal-research-agent.md`,
`logic-research-agent.md`, `math-research-agent.md`, `physics-research-agent.md` has exactly one
`### Recommendations` occurrence, nested under `## Findings` beside `### Cross-Domain Synthesis`,
and a `**Copy source**: general-research-agent.md's Stage 6...` note — but zero occurrences of
"validate-artifact" and zero copies of the verbatim contract. Extracting each file's literal
embedded skeleton (via a line-based fence parser, not a naive regex — see Appendix for why a
naive regex mis-pairs fences in these files) and running the real `validate-artifact.sh` against
each confirms: **all four currently PASS**. The defect is a drift/burial risk, not a present
failure — exactly project 166's finding, now re-verified against the real script rather than
inferred.

**Fixture reproduction** (built and run during this research pass, not asserted from memory):
- A report containing only `## Context Extension Recommendations` (no `## Recommendations`/
  `### Recommendations` anywhere) → `validate-artifact.sh` reports exactly
  `[ERROR] Missing required section: ## Recommendations` → `[FAIL] 1 error(s)`. This matches the
  real BimodalLogic report's shape and the exact error class recorded in that repo's
  `iss_1793906824199_f2HBxS`.
- The same report with `### Recommendations` added nested under Findings (formal's current
  shape) → `[PASS]`.
- The same report with `## Recommendations` added at top level → `[PASS]`.

**Near-miss (b) does not currently apply to formal**: none of the four skeletons contain
`## Context Extension Recommendations` or `## Recommended Next Steps` at all — only contributing
factor (a) (burial) is live in formal's own skeletons. The BimodalLogic production report DID
carry `## Context Extension Recommendations` as a late section, confirming the near-miss trap is
a real risk for an agent extending the skeleton, even though the skeleton itself doesn't suggest
that heading.

### Scope Item (4): Cross-Extension Sweep

Method: every `agent-system/extensions/*/agents/*.md` file was scanned for fenced code blocks via
a line-based fence parser (handles indented fences and mixed language tags that a naive
"```markdown...```" regex mis-pairs — see Appendix). Each block titled `# Research Report...` /
`# ...Report: ...` or `# ...Summary...` was checked against the validator's own `REPORT_SECTIONS`/
`SUMMARY_SECTIONS` arrays using its own `^##+ {section}` regex. A sample of results was then
cross-checked against the real `validate-artifact.sh` binary (not just the regex re-implementation)
to rule out false positives from the extraction method.

**PASS (skeleton conforms)**:
- `core/general-research-agent.md` (report) — canonical source, carries the full contract.
- `core/general-implementation-agent.md`, `lean/lean-implementation-agent.md`,
  `lean/lean-implementation-hard-agent.md`, `cslib/cslib-implementation-agent.md` (summary).
- `lean/lean-research-agent.md`, `lean/lean-research-hard-agent.md` (report) — already remediated
  by completed project 137, the model scope item (4) points to; confirmed still conforming.
- `nix/nix-research-agent.md`, `nvim/neovim-research-agent.md` (report).
- `formal/{formal,logic,math,physics}-research-agent.md` (report) — conforming as-is; see above
  for why this is a drift risk, not a current failure.

**FAIL — new gaps, mechanically confirmed, directly adjacent to this task's own scope**:
| Agent | Kind | Missing (validator's exact array) |
|---|---|---|
| `nix/nix-implementation-agent.md` | summary | Impacts, Follow-ups, References |
| `nvim/neovim-implementation-agent.md` | summary | Impacts, Follow-ups, References |
| `web/web-implementation-agent.md` | summary | Impacts, Follow-ups, References |
| `web/web-research-agent.md` | report | Context & Scope |

These four were spot-checked against the real `validate-artifact.sh` binary (not just the regex
re-implementation) on `nix-implementation-agent.md` and `web-research-agent.md`; both reproduced
the same missing-section list the script reports on real malformed artifacts.

**FAIL — a larger, separate, pre-existing gap class (domain-customized report shapes)**: eight
founder-extension agents (`analyze-agent.md`, `deck-builder-agent.md`, `deck-research-agent.md`,
`finance-agent.md`, `founder-implement-agent.md`, `founder-spreadsheet-agent.md`,
`legal-council-agent.md`, `market-agent.md`, `strategy-agent.md`), three present-extension agents
(`budget-agent.md`, `slide-critic-agent.md`, `slides-research-agent.md`), and two
epidemiology-extension agents (`epi-research-agent.md`, `epi-implement-agent.md`) write heavily
domain-customized report/summary shapes (`## Summary` instead of `## Executive Summary`;
`# Study Design Report`/`# Talk Research Report`/`# Slide Critique Report` instead of
`# Research Report`; no `## Decisions`, `## Recommendations`, `## Impacts`, `## Follow-ups`, or
`## References` headings at all in most of them) that nonetheless land under
`specs/{NNN}_{SLUG}/reports/*.md` or `/summaries/*.md`. Confirmed by reading each agent's own
"Create research report at ..." / "Write to ..." path line. Because
`skill-base.sh`'s `skill_validate_task_artifacts` sweep is a **path-convention** check
("`reports/*.md -> report`, `summaries/*.md -> summary`"), it is applied to these agents'
artifacts exactly as it is to every other extension's, regardless of `task_type` — so all of
these are genuinely, currently subject to the same `REPORT_SECTIONS`/`SUMMARY_SECTIONS` check and
almost certainly fail it in production whenever these agents run, non-blockingly. This is a
substantially larger and apparently older gap than the one this task was filed for; it long
predates this task and is out of scope for a fix here.

**A distinct, arguably worse gap found in the same sweep**: `typst-research-agent.md`,
`z3-research-agent.md`, `books-research-agent.md`, `latex-research-agent.md`,
`python-research-agent.md`, `rust-research-agent.md`, and `cslib-research-agent.md` carry **no
embedded report skeleton at all** — their "Create Research Report" stage is a single line
("Write to `specs/{N}_{SLUG}/reports/MM_{short-slug}.md`") with **no structural guidance and no
pointer to `report-format.md` or `general-research-agent.md`** anywhere in the file. This is a
different failure shape than formal's burial problem (there is nothing to bury — there is no
skeleton to deviate from), but it offers the authoring agent even less signal about the required
shape than formal's buried-but-present skeleton does. Not a `## Recommendations` conformance
failure in the sense this task measures (nothing to grep), but a related and arguably prior risk
worth flagging for the same sweep.

### External Resources

Not applicable — this is a pure codebase/validator investigation; no external documentation was
consulted.

## Decisions

1. **Single referenceable home, not a fourth/fifth copy**: the verbatim required-heading
   contract (five headings, `^##+ {section}` regex, exact-text-not-fuzzy warning, both named
   near-misses) should be added to `context/formats/report-format.md` itself (and the parallel
   six-heading statement to `context/formats/summary-format.md`), replacing the current
   plain-prose "## Structure" list item for Recommendations with the fuller statement.
   `general-research-agent.md`'s existing copy and the four formal agents' new text should both
   be short pointers at this one canonical location, not independent restatements. Rationale:
   `report-format.md` is the document every report's own metadata already cites as its authority
   (`**Standards**: report-format.md, subagent-return.md`); project 166's remedy landing only in
   a *consumer* of that standard, and never in the standard itself, is the structural reason the
   fix stayed "half-applied" rather than a scoping accident. This remedy reaches only
   `agent-system/extensions/core/context/formats/*.md` (core context, not scripts, not other
   extensions' agents) plus the four formal agents' own files — both pre-authorized by this
   record's declared file_scope and description.

2. **Promote `### Recommendations` to top-level `## Recommendations`** in all four formal
   skeletons. This is recommended, not merely permitted. It removes contributing factor (a)
   structurally rather than relying on instruction-following (the exact mechanism that failed
   twice already), and — contrary to the dispatch's framing of this as a cost — it is actually a
   net structural *improvement*: `general-research-agent.md`'s own canonical skeleton already
   treats `## Recommendations` as a top-level sibling of `## Findings`/`## Decisions`/`## Risks &
   Mitigations`, not as a Findings subsection. The current nested placement in formal's four
   agents is itself the divergence from the canonical shape; promoting it brings formal back
   into alignment rather than away from it. The content (a prioritized list of recommendations)
   is unaffected — only its heading level and position relative to `### Cross-Domain Synthesis`
   change. Fixture-verified both ways (nested passes today; top-level also passes).

3. **A lightweight self-check belongs in the shared contract text, as a cheap complement to
   the existing postflight gate — not a redundant second invocation of `validate-artifact.sh`.**
   `orchestrator-postflight.sh` (Stage 6a) and `skill-base.sh` already run
   `validate-artifact.sh --fix` non-blockingly on every research report immediately after the
   agent returns — this already "reaches the validator" for every formal-agent report, exactly as
   it does for every other research agent's. The actual failure mode observed in production is
   not that this gate is missing; it is that the gate is **non-blocking and its warning is easy
   to leave unactioned** — the BimodalLogic report's omission was in fact only caught later, by
   an unrelated implementation-phase verification criterion that happened to re-run
   `validate-artifact.sh` on all three reports, not by the research-phase postflight warning
   firing right after the research dispatch. A full second `validate-artifact.sh` subprocess call
   from inside the agent would be redundant with postflight's own check (same script, same
   timing relative to "agent has finished writing the file") and would not, by itself, change
   anything, since the agent has no more editing opportunity after a bare validator run unless it
   is instructed to act on the result. The recommended, cheaper form: state in the same canonical
   contract block that before finalizing the report the agent should grep its own file for each
   of the five headings (`grep -qE "^##+ {section}" <path>` per heading) and add any missing one
   before proceeding to Stage 7 — i.e., turn the existing passive warning into an active
   pre-return check the agent itself can act on, while leaving the postflight gate in place as an
   independent safety net for whatever this narrower self-check misses (it only checks the five
   section headings, not metadata fields).

4. **The validator (`validate-artifact.sh`) was deliberately NOT changed.** Per the hard
   constraint and project 166's own ruling: the `^##+ {section}` any-depth-but-exact-text regex
   is correct and was re-confirmed here by fixture — a substring-style relaxation would let
   `## Context Extension Recommendations` satisfy a check for `Recommendations`, converting the
   real BimodalLogic failure into a silent false pass. No change was made or is recommended to
   `REPORT_SECTIONS`, `SUMMARY_SECTIONS`, or the matching regex.

5. **The scope-item-(4) sweep's two further gap classes (the eight founder + three present + two
   epidemiology domain-shaped agents, and the seven skeleton-less agents) are recorded but
   explicitly left unfixed here.** They fall outside this record's declared file_scope (the four
   formal agents) and the hard constraint requires widening file_scope at plan time before any
   remedy reaches them. Recommendation: file at least one separate record per affected extension
   (founder; present; epidemiology; the skeleton-less group spanning typst/z3/books/latex/python/
   rust/cslib), following completed project 137's shape (give each agent its own conforming
   report/summary skeleton with a pointer to the single canonical contract from decision 1) rather
   than folding the fix into this task.

## Risks & Mitigations

- **Risk**: moving the verbatim contract out of `general-research-agent.md` into
  `report-format.md` could be read as weakening that agent's own self-contained instructions.
  **Mitigation**: keep a short, explicit pointer sentence in `general-research-agent.md` at the
  same Stage 6 location naming the exact file and anchor, so the instruction is still reachable
  inline without duplicating its text.
- **Risk**: promoting `### Recommendations` to `## Recommendations` touches a shape every
  consumer of a formal-agent report (an implementation agent reading `## Findings` for
  domain-specific content) may expect. **Mitigation**: none of the four agents' own
  "Copy source" language commits to any downstream consumer parsing nested structure
  programmatically; the move is additive to heading level only, not content, and is
  fixture-verified not to break validation either way.
- **Risk**: the self-check (decision 3) could itself drift out of sync with `REPORT_SECTIONS` if
  hand-copied into multiple agents. **Mitigation**: state it once in the same canonical
  `report-format.md` location as the contract itself, so any future change to the five headings
  is visible in exactly one place to both the check and the contract it enforces.
- **Risk**: the sweep's two further gap classes (decision 5) are large; leaving them unfixed
  means `validate-artifact.sh` will keep firing non-blocking warnings for every founder/present/
  epidemiology research or implementation dispatch in the meantime. **Mitigation**: this is
  already the status quo (pre-existing, not introduced by this task) and is explicitly called out
  here rather than silently left for a future report to re-discover from scratch.

## Context Extension Recommendations
- **Topic**: single canonical home for artifact-skeleton conformance contracts.
- **Gap**: `context/formats/report-format.md` and `summary-format.md` state the required
  sections in prose but not with the verbatim/regex/near-miss treatment that actually prevents
  drift; that treatment currently lives only inside one consumer agent file.
- **Recommendation**: fold the verbatim contract into both format standard files directly (see
  Decision 1), so every future new research/implementation agent across any extension inherits
  it from the standard it is already required to cite, rather than needing its own project-166-
  style remediation task.

## Recommendations
- Add the verbatim required-heading contract (five headings for report, six for summary, the
  `^##+ {section}` regex statement, the exact-text-not-fuzzy warning, both named near-misses) to
  `context/formats/report-format.md` and `context/formats/summary-format.md` as the single
  canonical home; convert `general-research-agent.md`'s existing copy, and new text in the four
  formal agents, to short pointers at that location.
- Promote `### Recommendations` to top-level `## Recommendations` in all four formal research
  agents' skeletons (`formal-research-agent.md`, `logic-research-agent.md`,
  `math-research-agent.md`, `physics-research-agent.md`), keeping `### Cross-Domain Synthesis` and
  the per-domain findings subsections unchanged otherwise.
- Add a cheap, grep-based pre-return self-check to the same canonical contract text (not a second
  `validate-artifact.sh` invocation), instructing the authoring agent to verify and, if needed,
  add any missing required heading before writing `.return-meta.json`.
- Do not modify `validate-artifact.sh`'s matching logic.
- File separate follow-up records (one or more) for: (a) the four confirmed small gaps in
  `nix-implementation-agent.md`, `neovim-implementation-agent.md`, `web-implementation-agent.md`,
  `web-research-agent.md`; (b) the larger founder/present/epidemiology domain-shaped-report gap
  (11 agents); (c) the seven skeleton-less research agents
  (typst/z3/books/latex/python/rust/cslib) that have no report structure guidance at all. Widen
  file_scope at plan time for whichever of these is picked up.

## Appendix

**Why extraction needed a line-based fence parser, not a `` ```markdown...``` `` regex**: several
agent files use fences with no language tag (bare ` ``` `) or an indented fence inside a numbered
list. A naive regex `` '```[lang]*\n(.*?)\n```' `` applied via `re.findall` mis-pairs fences
whenever an opening fence's language-tagged form (e.g. `` ```json ``) appears before the true
bare closing fence is reached in scan order, because the regex's closing pattern (`` \n``` ``)
also matches the start of a *tagged* fence line, silently merging two separate blocks and
corrupting the extracted content (observed directly on `general-research-agent.md`, where a naive
extraction merged the Stage-4.5 `jq` one-liner block with everything up to the next `` ```json ``
block, skipping the real skeleton block entirely). The line-based parser used throughout this
report instead tracks fence state per line and only closes a block on a fence line carrying no
language tag, matching CommonMark's own closing-fence rule.

**Commands used for the fixture reproduction and the skeleton re-verification**:
```bash
bash agent-system/extensions/core/scripts/validate-artifact.sh <path> report
bash agent-system/extensions/core/scripts/validate-artifact.sh <path> summary
```
run against: (1) a hand-built fixture reproducing the exact BimodalLogic failure shape and its
two corrected variants; (2) each formal agent's literal embedded skeleton, extracted verbatim by
the line-based parser; (3) a spot-check sample of two of the newly-found gaps
(`nix-implementation-agent.md`, `web-research-agent.md`).

**Cross-repo reference** (read-only, for provenance, not modified): the production failure's own
issue-log entry and report are at
`~/Projects/BimodalLogic/specs/878_lplus_ztime_decidability_paper_proof_repair/issues.jsonl`
(`iss_1793906824199_f2HBxS`) and
`~/Projects/BimodalLogic/specs/878_lplus_ztime_decidability_paper_proof_repair/reports/01_lplus-ztime-decidability-proof-repair.md`.
