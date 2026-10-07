# Research Report: Record-editing guardrails and the convention-maintenance context pointer

- **Task**: 341 - Record-editing guardrails and the convention-maintenance context pointer
- **Started**: 2026-10-05
- **Completed**: 2026-10-05
- **Effort**: half to one working day (one rule file under 70 lines, one context file, one pointer line, registration)
- **Dependencies**: the books-extension split-retarget task (anchors + pin) — CONFIRMED LANDED (see Findings)
- **Sources/Inputs**:
  - Seed report: `specs/341_record_editing_guardrails_convention_pointer/reports/01_seed-record-editing-guardrails.md`
  - `agent-system/extensions/books/rules/books.md` (source store; style model)
  - `agent-system/extensions/books/EXTENSION.md`, `manifest.json`, `index-entries.json`, `README.md` (source store)
  - `agent-system/extensions/lean/context/project/lean4/README.md` (source store)
  - `~/Projects/Logos/Verification/docs/book-convention/17-documentation-reconciliation-and-book-health.md`
  - `~/Projects/Logos/Verification/docs/book-convention/19-convention-versioning-and-lockstep.md`
  - `~/Projects/Logos/Verification/docs/book-convention-evidence/README.md`
  - `~/Projects/Logos/Verification/docs/book-evidence.md`
  - `~/Projects/Logos/Verification/books/scripts/lint-validated-by.sh`, `check-citation-inventory.sh`
  - `agent-system/extensions/books/scripts/books-observe.sh`
  - `agent-system/extensions/books/context/project/books/patterns/books-review-submode.md`, `books-revise-submode.md`
  - `agent-system/extensions/core/scripts/check-extension-docs.sh` (Rule U, Rule I)
  - `agent-system/extensions/core/context/formats/return-metadata-file.md`
- **Artifacts**: this report
- **Standards**: source-store-deploy-boundary.md, no-task-references-in-deliverables.md, report-format.md

## Executive Summary

- The seed report's seven-obligation draft is substantively correct and every anchor it cites
  resolves to real text. This report re-verifies each anchor against the live Verification repo
  and the books-extension source store, and corrects one point: **the dependency this task waits
  on has already landed**, so obligation 7 no longer needs conditional wording — Decision 19
  exists, is `active`, and the extension's `convention_version` pin already exists
  (`manifest.json`: `"convention_version": "0.1.0-pre"`, `"measured_at_commit": "d255518"`).
- `EXTENSION.md` is currently at **exactly 60 lines**, the Rule U cap, with zero slack. Any
  addition the plan makes there (e.g. a line pointing at the new rule/context file) must trim an
  equal number of lines elsewhere in the same file, or the gate fails.
- `rules/books.md` is **69 lines**, one under its own 70-line analog — confirming "under 70
  lines" for the new rule is a tight, previously-exercised budget, not a loose one.
- Registering the new rule in `index-entries.json` covers context-file discovery, but the new
  rule file itself is not an `index-entries.json`-governed artifact (rules load by `paths:` glob
  match, not by the index). The new rule DOES need an entry in `manifest.json`'s
  `provides.rules` array — `check-extension-docs.sh`'s Rule I checks deployed-vs-source drift for
  every `manifest.provides.rules` entry, and an unlisted rule file is invisible to that check
  (and to `EXTENSION.md`'s own "provides" accounting). The dispatch's Registration section names
  only `index-entries.json` and `EXTENSION.md`; `manifest.json` is a third file the plan should
  also touch for the rule and the context pattern to be formally "provided" by the extension.

## Context & Scope

In scope (restated from the dispatch, confirmed unchanged by this research):
`rules/book-convention-record.md` (new, under 70 lines, seven obligations with anchors);
`context/project/books/patterns/record-maintenance.md` (new, diagnostics map only, no
substance); one pointer line in `agent-system/extensions/lean/context/project/lean4/README.md`;
registration in `index-entries.json` and `EXTENSION.md` (and, per the finding above,
`manifest.json`). Out of scope: any change to the convention's substance, hooks, repo-side
files, and the books-extension context-corpus refactor (a separate, currently `[HOLD]` task).

## Findings

### Dependency is satisfied — obligation 7 should NOT be conditional

The dispatch instructs: "WORD THIS CONDITIONALLY until that decision exists, then tighten it in
the same change that bumps the pin." Checking the live repo:

- `docs/book-convention/19-convention-versioning-and-lockstep.md` exists, `**Status**: active`,
  `**Last approved**: 2026-10-05`. Its Decision body gives the exact bump-rule table (major/minor/
  patch keyed to: a decision retired/reversed or a binding clause's meaning changed → major,
  shipped as minor while `0.y.z`; a new decision or an obligation-adding amendment → minor; a
  marker promotion, evidence-only change, present-tense reword, or index/cross-link change →
  patch; the alpha-stamp transition and any edit under `specs/` → none).
- The pin already exists: `agent-system/extensions/books/manifest.json` carries
  `"convention_version": "0.1.0-pre"` and `"measured_at_commit": "d255518"`; the corpus
  `README.md` states it in prose ("`convention_version: \"0.1.0-pre\"` (`manifest.json`,
  `measured_at_commit: \"d255518\"`) is this corpus's own pin of the record's text").
- Git history confirms the dependency task (the split-retarget task) is `completed`
  (`specs/state.json`; commit `acef73be4 task 340 phase 6: the convention-version pin and the
  non-blocking preflight comparison`, `2054345cd task 340 phase 7: line-count reconciliation and
  the full gate sweep`).

**Conclusion**: obligation 7 can and should be written in its tight, unconditional form now —
citing Decision 19's table directly and naming the pin's two concrete locations
(`manifest.json`'s `convention_version` field; the corpus README's mirrored sentence) — rather
than the dispatch's anticipated fallback conditional wording. This is a correction to feed into
planning, not a scope change: the dispatch itself names this exact "tighten in the same change"
path as the intended outcome once the dependency lands, and it has landed.

### Deliverable 1 — the seven obligations, each anchor re-verified

1. **Binding marker → stop/research/escalate/amend+marker.** Verified verbatim in
   `docs/book-convention/17-documentation-reconciliation-and-book-health.md`, "### Decision",
   "**The escalation protocol**" bullets: "A decision whose Validated-by marker names an
   instance is binding," and "Work that cannot satisfy a binding clause stops. It then (a)
   researches ... (b) escalates it to the repository owner for a ruling; and (c) lands that
   ruling as an amendment to the clause's text plus an updated Validated-by marker on the
   decision, and bumps the convention version line per Decision 19."
2. **Neither silent departure nor silent compliance.** Same section, verbatim: "Both silent
   departure and silent compliance are refused."
3. **`none yet` is a hypothesis, promoted by first exercise.** Same section, verbatim: "a clause
   marked `none yet` is a hypothesis, not a constraint. It needs no escalation and may be amended
   in place by the work that first exercises it, which then promotes its marker."
4. **Split-record edit contract.** `docs/book-convention-evidence/README.md`, "Ruling 5's
   file-split mechanics paragraph" section, verbatim: "'an updated Validated-by marker' means
   editing that file's one-line marker **and** appending a new dated entry to the decision's
   paired file under `docs/book-convention-evidence/`." The marker and evidence-file templates
   (with the `<value>` vocabulary — `<instance>` / `partially, <instance> — <clauses>` /
   `none yet` — and the four event kinds `Newly exercised`/`Extended`/`Amended`/`Re-measured`)
   are in the same README's "Reduced marker template (Ruling 3)" and "Evidence file template"
   sections.
5. **No new artifact, no register; marker is the status.** Decision 17's "**No new artifact**"
   paragraph, verbatim: "the marker is the status ... an amended clause is the resolution ...
   the existing per-task decision record is where a ruling lands (`.decisions.json`...)."
   `docs/book-evidence.md`'s "The review protocol" section states the no-register rule
   explicitly: "**The harness computes and proposes; it never decides.**" ... "**The no-register
   rule, stated explicitly.** Nothing tracks a proposal between its emission and its triage,"
   with the triage vocabulary "**revise now**", "**defer**", "**reject**".
6. **Durable anchors; never a task number; zero-citation-loss.** `rules/no-task-references-in-
   deliverables.md` (this repo) states the general rule; `check-citation-inventory.sh`'s header
   confirms the multiset guarantee: "a span moving from one file to another ... is a pass; a span
   disappearing from the set entirely is a FAIL."
7. **Version bump — now unconditional** (see correction above). Decision 19's bump-rule table is
   the citation; the pin's two locations (`manifest.json` field, README mirror sentence) are the
   "say so" target when the pin goes stale.

### Deliverable 2 — the diagnostics map, verified

- `lint-validated-by.sh` header (verbatim): "CHECK 1, CHECK 2, and -- once `docs/book-convention/`
  exists -- CHECK 5 through CHECK 8 are BLOCKING (exit 1 on any finding) ... CHECK 3 and CHECK 4
  are ADVISORY (printed, never change the exit code)." CHECK 1 = marker presence/well-formedness;
  CHECK 2 = instance liveness; CHECK 3 = marker-promotion-owed (advisory); CHECK 4 = unescalated
  departure (advisory); CHECK 5 = cross-link integrity; CHECK 6 = anchor liveness; CHECK 7 =
  index/content agreement; CHECK 8 = orphaned-decision detection.
- `check-citation-inventory.sh` is the separate zero-citation-loss multiset guard, confirmed
  above.
- The snapshot probe: `agent-system/extensions/books/scripts/books-observe.sh` tests for and
  invokes an *executable in the consuming repository*, `books/tool/book-snapshot.sh --diff
  <before> <after> --json` (the extension ships no snapshot probe itself — "PROBE OWNERSHIP
  BOUNDARY (D3)"). The observer is `books-observe.sh` itself (topic/task_type-keyed, advisory,
  non-blocking, one `book.observation.json` per books-topic task).
- `/books --review` is confirmed strictly read-only: `books-review-submode.md` verbatim,
  "**Strictly read-only.** `--review` never proposes and never writes ... It never creates a
  task, never edits the books convention, and never advances any watermark." `/books --revise`
  is confirmed to never edit the record: `books-revise-submode.md:204` verbatim, "**`--revise`
  NEVER edits the books convention.** It proposes tasks; the tasks do the work."
- Record locations (from `docs/book-evidence.md`'s table): SNAPSHOT —
  `specs/books-evidence/snapshot-{ISO_DATE}.json` (one file per snapshot, append-only directory);
  RUN — `specs/books-evidence/runs.jsonl` (one shared append-only log); OBSERVATION —
  `specs/{NNN}_{SLUG}/book.observation.json` (one per task). "The repository owns probes" is the
  same document's own framing: the extension's observer joins `issues.jsonl`/`metrics.jsonl` with
  books-specific facts and invokes a probe that lives in the *consuming* repository, never
  shipping one itself.

### Deliverable 3 — the pointer's layering is a deliberate inversion, and it is safe

`agent-system/extensions/lean/manifest.json` declares `dependencies: ["core", "literature"]` —
it does not depend on `books`. The dependency direction is the other way (`books` depends on
`["core", "lean", "typst"]`), so the lean4 README pointing into the books corpus is a one-way,
cross-extension reference against the normal dependency arrow. This is exactly what the dispatch
asks for and names the reason (14 of 14 books-topic tasks in the consuming repo are `lean4`-
typed), and it is low-risk: the pointer is a single plain-text line in a markdown README, not a
`load_when`/`paths:` mechanism — if the `books` extension is not loaded in some other deployment,
the line is an inert, harmless cross-reference, never a broken load path. `lean4/README.md` is
currently 29 lines with a flat `## Key Files` bullet list (no cap found for this file in
`check-extension-docs.sh`'s rule set, unlike `EXTENSION.md`'s Rule U) — there is no line-budget
collision here.

### Registration mechanics, verified

- `EXTENSION.md` is **exactly 60 lines today** (`wc -l` = 60), matching Rule U's cap with zero
  margin. `rules/books.md` is **69 lines**, one line under its own 70-line budget for the new
  rule file. Any text the plan adds to `EXTENSION.md` (e.g., a one-line pointer to the new rule
  and context file, mirroring the existing "Book Directory Layout" / "Observer" line-pointer
  style already used in that file) must be offset by trimming elsewhere in the same file, or Rule
  U fails the gate.
- `index-entries.json` currently has 21 entries (the seed report's "twenty" count is the
  `README.md` navigation-table figure, not the registered-entry count — the two numbers are
  already one apart today and will be two apart once `record-maintenance.md` is added without
  also touching the nav table). Two entries use eager `load_when` (README.md and
  signal-tagging.md, both loaded for all four books agents under `task_types: ["books"]`); the
  other nineteen are `"on_demand": true` with empty `load_when`, reachable only via the README's
  navigation table or a cross-reference. `record-maintenance.md` fits the on-demand majority
  pattern (it is read only when a dispatch is actually amending the convention record, not on
  every books task), so the natural registration shape is `"on_demand": true`, empty
  `load_when.agents`/`load_when.task_types`, `domain: "project"`, `subdomain: "books"`.
- `manifest.json`'s `provides.rules: ["books.md"]` and `provides.context: ["project/books"]`
  arrays are what `check-extension-docs.sh`'s Rule I drift-check and the deploy tooling treat as
  the extension's declared file inventory. `provides.context` is a directory reference (covers
  any new file under `context/project/books/` automatically), but `provides.rules` is a literal
  filename array that will not include `book-convention-record.md` unless the plan adds it
  explicitly — this file is not named anywhere in the dispatch's Registration section, which is
  an omission this report flags for the plan rather than one this research phase should decide
  unilaterally.
- Because `record-maintenance.md` would be the 22nd entry in `context/project/books/` but
  `README.md`'s navigation table and its own prose currently describe "twenty docs" /
  "twenty-row table," leaving the nav table unedited would make the new file registered
  (findable via `index-entries.json`) but undiscoverable via the corpus's own navigation index.
  A separate task (`342`, title "Refactor the books extension's context corpus against the
  settled convention: role-scoped loading, agent-set review, version-pinned files", currently
  `[HOLD]`) exists specifically to rework this corpus's role-scoped loading end to end and
  explicitly lists the version-pin and anchor dependency this task also has. Adding one row to
  the nav table now is a small, compatible edit that keeps the new doc discoverable without
  pre-empting 342's larger rework; leaving it for 342 is also defensible since 342 will touch
  every row anyway. This is a planning-level choice, not a research-level one — flagged rather
  than resolved here.

## Decisions

- Obligation 7 is written unconditionally (Decision 19's bump-rule table cited directly, the
  pin's two locations named), not with the dispatch's fallback conditional wording, because the
  dependency has already landed. This is the one substantive update this research makes to the
  seed report's draft.
- The plan should register the new rule in `manifest.json`'s `provides.rules` array (alongside
  `index-entries.json` and `EXTENSION.md`), even though the dispatch's Registration section names
  only the latter two — `provides.context` already auto-covers the new context file via its
  directory-level reference, but `provides.rules` is filename-literal and will not.
- Whether to add a nav-table row to `context/project/books/README.md` for the new context file is
  left to the plan; both leaving it for task 342 and adding one row now are defensible, and
  either is compatible with this task's "no mechanism" scope boundary (a nav-table row is prose,
  not a mechanism).

## Recommendations

1. **Rule file** (`rules/book-convention-record.md`, new): `paths:` line first (no frontmatter
   delimiters, matching `rules/books.md`'s own convention) —
   `paths: ["**/docs/book-convention.md", "**/docs/book-convention/**", "**/docs/book-convention-evidence/**"]`.
   Seven numbered obligations, each ending in a parenthetical anchor, mirroring `rules/books.md`'s
   per-item "measured failure mode" framing for obligation 1 (the escalation protocol) since that
   is the item with an actual measured failure history (the 0% in-place-reduction / 72 KB
   marker-mass finding that motivated the file split, per the seed report's own citation chain).
   Keep strictly under 70 lines — `rules/books.md`'s own 69-line precedent leaves no slack to
   spare; favor terse restatement over elaboration. Add a short "Scope Boundary" line (mirroring
   `rules/books.md`'s own closing section) noting this rule governs editing the record, not the
   record's substance, and pointing to `context/project/books/patterns/record-maintenance.md` for
   the diagnostics.
2. **Context file** (`context/project/books/patterns/record-maintenance.md`, new): state, in
   order: (a) the four scripts/mechanisms and their blocking/advisory/structural split exactly as
   verified above (CHECK 1/2 blocking, CHECK 3/4 advisory, CHECK 5-8 structural; plus
   `check-citation-inventory.sh`'s multiset guard as a separate tool); (b) the snapshot probe
   (named path, invoked by the observer, lives in the consuming repo) and the observer
   (`books-observe.sh`, what it writes and where); (c) the review/revise read-only/never-edits
   facts with their exact citations; (d) "the repository owns probes" framing; (e) the three
   record locations (SNAPSHOT/RUN/OBSERVATION paths). Omit anything about clause content, marker
   values, or the escalation protocol's substance — that is the rule file's and the record's own
   job.
3. **Pointer line** (`agent-system/extensions/lean/context/project/lean4/README.md`): one bullet
   under `## Key Files`, in the same style as the existing rows, e.g. `- books convention record
   maintenance: see the books extension's \`context/project/books/patterns/record-maintenance.md\`
   for diagnostics and the escalation protocol when a dispatch amends \`docs/book-convention*\`.`
   Keep it to one line; no new section header needed given the file's flat bullet-list structure.
4. **Registration**: add `book-convention-record.md` to `manifest.json`'s `provides.rules` array;
   add one `index-entries.json` entry for `record-maintenance.md` (`on_demand: true`, empty
   `load_when`, `domain: "project"`, `subdomain: "books"`); add a one- or two-line mention in
   `EXTENSION.md`, trimmed against the existing 60-line budget (candidate: fold it into the
   existing "Book Directory Layout" or "Observer" bullet rather than adding a new `###` heading,
   to avoid net growth). Verify with `check-extension-docs.sh` (Rule U and Rule I) and
   `check-task-references.sh` (zero task numbers in both new files) before closing the phase.
5. Leave the `context/project/books/README.md` navigation-table decision (add a row now vs. defer
   to task 342) to the plan; this research does not recommend one over the other.

## Risks & Mitigations

- **Risk**: adding prose to `EXTENSION.md` pushes it past the Rule U 60-line cap. **Mitigation**:
  the file is at exactly 60 lines today with no slack — budget the addition against an equal
  trim, and verify with `check-extension-docs.sh` before considering the phase done.
- **Risk**: `manifest.json`'s `provides.rules` array is left unedited, so the new rule file is
  deployed (via `provides.context`'s directory-level or `rules/` glob behavior, if any) but not
  accounted for by Rule I's drift check. **Mitigation**: explicitly add the filename to
  `provides.rules` as part of this task's registration step, not deferred to a later task.
- **Risk**: wording obligation 7 conditionally (as the dispatch's fallback anticipated) when the
  dependency has already landed would understate what is actually knowable today and would need
  a near-immediate follow-up edit. **Mitigation**: write it unconditionally now, citing Decision
  19's table and the pin's two locations directly (see Decisions above).

## Context Extension Recommendations

- **Topic**: cross-extension documentation pointers against the dependency arrow (a dependency's
  README pointing into a dependent's content, as this task's Deliverable 3 does).
  **Gap**: no existing guide names this pattern or states why it is safe (inert prose, not a
  load-bearing mechanism). **Recommendation**: if this pattern recurs for other dependency pairs,
  a short note in `context/guides/extension-development.md` would save a future task from
  re-deriving the "is this safe" analysis this report did.

## Appendix

- Search/verification commands used: `wc -l` on `EXTENSION.md`, `rules/books.md`,
  `index-entries.json`; `grep -n "CHECK [0-9]"` over `lint-validated-by.sh`; `grep -n "read-only|
  never edit"` over `books-review-submode.md`/`books-revise-submode.md`; `grep -n "snapshot|
  probe"` over `books-observe.sh`; direct reads of Decision 17, Decision 19, the evidence
  README's Ruling 5 section, and `docs/book-evidence.md`'s review-protocol section in
  `~/Projects/Logos/Verification`.
- `specs/state.json` and recent git log confirm the split-retarget dependency task (commits
  `acef73be4`, `2054345cd`, task-prefixed `task 340 phase N: ...`) is `completed`.
