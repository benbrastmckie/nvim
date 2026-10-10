# Research Report: Null `resolution` Entries Unreachable by the Conclusion Stage

**Task**: 373 - Issue-log entries with a null resolution are permanently invisible to the conclusion stage that exists to act on them
**Started**: 2026-10-10T00:18:00Z
**Completed**: 2026-10-10T00:25:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/issue-record.sh`, `orchestrate-conclusion-aggregate.sh`, `context/formats/issue-log.md`, `context/contracts/conclusion-stage.md`, `context/patterns/orchestrate-batch-results-template.md`, `scripts/tests/test-orchestrate-conclusion-aggregate.sh`
- Live fixture data: `~/Projects/BimodalLogic/specs/archive/739_e2_depth_two_stratification_shared_stratum_falsifier/issues.jsonl`, `.../740_ktype_summary_finite_preds_restatement/issues.jsonl`
- Full-tree grep for `issues.jsonl` and `issue-record.sh` call sites across `agent-system/extensions/`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is confirmed exactly as described: `issue-record.sh` writes an explicit JSON
  `null` when `--resolution` is omitted on a `kind: "issue"` entry; `issue-log.md` declares that
  null schema-legal but silent on its meaning; `orchestrate-conclusion-aggregate.sh`'s filter
  (`.resolution // ""`) coerces null to `""`, which matches neither `"open"` nor
  `"worked_around"`, dropping the entry with no diagnostic.
- **Recommended primary remedy: Option 2 (widen the reader)** — change the aggregator's
  coalesce target from `""` to `"open"` — composed with a lightweight tally addition (the
  `3`-compatible half of Option 3) that reports how many classified entries arrived via an
  implicit null versus an explicit `"open"`. **Option 1 (tighten the writer) is ruled out as the
  sole remedy**: it cannot, by itself, satisfy the dispatch's mandatory regression-fixture
  acceptance test, because the six already-written entries in the BimodalLogic fixture are
  append-only and this task is explicitly barred from retroactive edits.
- All six cited defect-instance entry_ids, their `class`/`resolution` values, and the one
  correctly-exempted `kind: "win"` entry were verified byte-for-byte against the live fixture
  files — the dispatch's evidence enumeration needed no correction.
- Full call-site enumeration (required before committing to any writer change) found that
  **every existing hardcoded engine call site already passes `--resolution` explicitly**
  except one (`git-commit-phase.sh:264`, "scope excursion"); the real gap is the
  agent-facing dispatch-file template, which leaves `--resolution` as agent discretion — and the
  one real fixture available shows agents omit it almost universally. This is independent
  support for why Option 2 is the right place to absorb the omission, rather than trying to
  police every future agent dispatch into supplying it.
- One imprecision in the dispatch's own sub-question answers was found and corrected (see
  Findings): `issue-record.sh`'s `issues.jsonl` is read by a second consumer,
  `agent-system/extensions/books/scripts/books-observe.sh`, but that consumer never reads or
  filters on `.resolution`, so the dispatch's bottom-line "no blast radius outside the
  conclusion stage" claim still holds once corrected to "sole consumer of the `resolution`
  field," not "sole reader of the file."

## Context & Scope

**In scope** (per dispatch): deciding and documenting what a null `resolution` means on a
`kind: "issue"` `issues.jsonl` entry, picking one primary remedy among the three the dispatch
poses, and identifying every doc (`issue-log.md`, `conclusion-stage.md`) and code location that
must change to state that meaning explicitly. The dispatch explicitly reserves `file_scope` for
plan time, pending the remedy choice this report makes.

**Out of scope** (per dispatch, not revisited here): the three-channel derivation contract, the
per-channel approval gates and ledger, the `kind: "win"` exemption, retroactive edits to
already-written `issues.jsonl` entries in any repo, the roadmap-generator and
conclusion-report-block defects tracked by tasks #371/#372, and any closed-enum/open-enum class
drift observed incidentally (see Findings' noted-but-unaddressed item).

**Backlog reconciliation**: re-confirmed via the keyword sweep described in the dispatch
(`issue.log|issues\.jsonl|issue-record|resolution`) — no existing task covers this; #273 is
terminal and built the consumer half; #371/#372 are siblings on different conclusion-stage
defects with no declared dependency edge to this one.

## Findings

### The mechanism, verified line-for-line

- `agent-system/extensions/core/scripts/issue-record.sh:35-39` lists `--kind`, `--class`,
  `--severity`, `--what-happened`, and exactly one task-resolution form as the only required
  arguments; `--resolution` is validated only `if [ -n "$resolution_arg" ]` (line 190), and line
  387 writes `resolution: (if $resolution == "" then null else $resolution end)` — an omitted
  flag is indistinguishable, downstream, from an explicitly empty one, and both become JSON
  `null`.
- `context/formats/issue-log.md:94`'s `resolution` row: `no (nullable)`, closed three-value set
  `fixed_inline | worked_around | open`, empty Notes column. Schema-legal, meaning undefined.
- `scripts/orchestrate-conclusion-aggregate.sh:253`:
  `map(select(.kind != "win" and ((.resolution // "") as $r | $r == "open" or $r == "worked_around")))`
  — `null // ""` evaluates to `""`, which fails both disjuncts, silently excluding the entry from
  `$candidates` (and therefore from `$proposals`).
- `context/contracts/conclusion-stage.md:52-54` ("The Filter Predicate") states the `open`/
  `worked_around` admission rule and the `fixed_inline` exclusion rule, but says nothing about a
  null or omitted value — exactly the silence the dispatch identifies as the root defect.

### Fixture verification (exact match, no corrections needed)

Read `~/Projects/BimodalLogic/specs/archive/739_e2_depth_two_stratification_shared_stratum_falsifier/issues.jsonl`
and `.../740_ktype_summary_finite_preds_restatement/issues.jsonl` directly (17 total lines across
both files). All six cited `kind: "issue"`, `resolution: null` entry_ids are present exactly as
named, with exactly the `class` values the dispatch quotes:

| Task | entry_id | class | kind | resolution |
|------|----------|-------|------|------------|
| 739 | `iss_1791491569197_zKdUqQ` | `tooling` | issue | null |
| 739 | `iss_1791491985760_3vcrAx` | `tooling` | issue | null |
| 739 | `iss_1791492027880_W6tDkM` | `tooling` | issue | null |
| 739 | `iss_1791493419356_KeoHGd` | `proof-repair` | issue | null |
| 740 | `iss_1791494232271_nNKsBs` | `gate-collision` | issue | null |
| 740 | `iss_1791494859307_glbAlq` | `gate-collision` | issue | null |

`iss_1791495145946_fTTfhl` (740) is confirmed `kind: "win"`, `class: "time-saved"`,
`resolution: null` — correctly exempted by the filter's win carve-out, exactly as the dispatch
states; not an instance of this defect.

**New observation, not previously flagged**: every one of the 17 entries across both fixture
files is `resolution: null` *except* the four marked `"fixed_inline"` (three in 739, one in
740). No entry anywhere in either file uses the literal value `"open"` or `"worked_around"`.
This is strong empirical evidence that, in practice, omitting `--resolution` means "I have not
yet decided this is closed" (i.e., functionally `open`), not "I am deliberately declining to
flag this" — the dispatch's Option 2 downside ("silently reclassifies entries whose authors may
have meant 'not worth acting on'") describes a distinction this real sample never actually
exercises. It also means the closed three-value enum currently has **no value that means
"deliberately not worth acting on"** at all — that intent isn't representable today regardless
of how null is treated, so merging null into `open`'s meaning does not remove an expressive
capability the schema currently offers.

### Call-site enumeration (required before committing to Option 1; informs why it is rejected)

Full grep of `agent-system/extensions/` for `issue-record.sh` invocations with `--kind issue`:

| Call site | `--resolution` present? |
|---|---|
| `orchestrate-cycle-postflight.sh` (4 sites: RECOVERY_DECLINED, deploy-pending-refusal, blocker-gated partial, OFF_SCHEMA_STATUS) | Yes, all 4 (`open`) |
| `orchestrate-cycle-plan.sh` (2 sites: MAX_INFRA_FAILURES, MAX_CYCLES) | Yes, both (`open`) |
| `git-commit-phase.sh:264` ("scope excursion") | **No** |
| `orchestrate-build-dispatch.sh:571` (the agent-facing `## Issue Log` dispatch template — the one every research/plan/implement dispatch, including this one, receives verbatim) | Optional by design — bundled into "`[other optional fields]`" |
| `agent-system/extensions/books/.../signal-tagging.md` (9 worked examples; 5 use `--kind issue`) | 3 of 5 (`a`, `f`, `g`); **2 omit it** (`c` guardrails_qa, and the "burden created" example) |

Every hardcoded **engine** call site already supplies `--resolution` explicitly except one
trivial case. The actual, high-volume source of null entries is dispatched-agent judgment
following the optional-field template — exactly the path that produced all six fixture
instances. This means Option 1's engine-side cost is nearly zero (one line in
`git-commit-phase.sh`), but its *problem-side* cost is high: it would require either making every
future dispatched agent reliably supply the field (a documentation/discipline fix with no
mechanical enforcement at the point agents actually omit it today) or accept that the defect
keeps recurring for every call site outside the hardcoded six.

### Why Option 1 cannot be the sole remedy

The dispatch's acceptance criteria include a **regression fixture** requirement, independent of
which option is chosen: re-running `orchestrate-conclusion-aggregate.sh --aggregate` over tasks
739 and 740 "must no longer silently return zero proposals while six issue entries sit
unreachable." Those six entries are already written, and the dispatch's own "NOT IN SCOPE"
section bars retroactive edits to already-written `issues.jsonl` entries. Tightening the writer
(Option 1) changes nothing about data already on disk — a re-run over the unmodified fixture
would still filter out all six entries and still return zero proposals, exactly as today. Option
1 therefore cannot, on its own, satisfy a hard acceptance requirement of this task. (The dispatch
itself names "1 and 2" as substitutes, not composable; this finding is the concrete reason why 1
alone fails where 2 succeeds.)

### Verifying the sub-question answers already given

- `suggested_channel`'s null-handling claim (aggregator line ~262 filters nulls out of the hint
  list) — confirmed correct on inspection; no issue here.
- **"THE AGGREGATOR IS THE SOLE CONSUMER of issues.jsonl" — imprecise as stated.** A repo-wide
  grep for `issues.jsonl` found `agent-system/extensions/books/scripts/books-observe.sh` also
  reads each task's `issues.jsonl` directly (joining `by_kind`/`dimension_signals`/`tags`/
  `burdens` for the books extension's observation record). This is a real second consumer the
  sub-question missed. However, a further grep for `.resolution` across `books-observe.sh` and
  its own docs (`observation-record.md`, `signal-tagging.md`) returns **zero** hits — that
  consumer never reads, filters, or branches on the `resolution` field at all. The dispatch's
  bottom-line conclusion ("a filter change has no blast radius outside the conclusion stage")
  therefore still holds, correctly restated as: the conclusion stage is the sole consumer *of the
  `resolution` field specifically*, not the sole reader of the file. This distinction matters
  for the plan phase: it confirms Option 2 is safe to land without touching the books extension,
  but the sub-question's original phrasing should not be repeated verbatim in any future
  document.
- `skill-todo/SKILL.md:354` and `skill-learn/SKILL.md:681` grep-confirmed to carry the quoted
  self-prohibition verbatim in substance, as the dispatch states.

### Test coverage gap

`scripts/tests/test-orchestrate-conclusion-aggregate.sh`'s Case (a) ("resolution filtering",
lines ~196-212) exercises `open`, `worked_around`, and `fixed_inline` explicitly but has **no
case for a null/omitted `--resolution`** — precisely the value that caused the live defect this
task exists to fix. This is itself a `missing cheap verification tier` instance: a cheap,
already-structured test suite could have caught this before it reached a live `/orchestrate`
run. Recorded as an issue-log entry on this task (see below) and carried into Recommendations.

## Decisions

- **Primary remedy chosen: Option 2 (widen the reader), composed with a lightweight tally
  addition (the "surface the gap" half of Option 3).** Option 1 is rejected as the sole remedy
  because it cannot satisfy the regression-fixture acceptance test against already-written,
  non-retroactively-editable data (see Findings). Option 3 alone is not chosen as the *primary*
  remedy because it would leave `proposals[]` empty for the 739/740 re-run — technically
  satisfying the letter of "no longer *silently*" but not the stronger, more useful outcome
  Option 2 achieves: the six entries becoming real, cited, actionable proposals.
- **Null and `"open"` are declared identical in meaning**, both read as "not yet resolved,
  candidate for classification." This is a documentation decision as much as a code one: both
  `issue-log.md`'s `resolution` row and `conclusion-stage.md`'s "The Filter Predicate" section
  must state this explicitly (dispatch's "WHICHEVER IS CHOSEN" requirement).
- **No change to `issue-record.sh` itself.** `--resolution` stays optional for every `--kind`;
  no new validation, no new required-field refusal. Zero writer churn, confirmed safe by the
  call-site enumeration above.
- **One exact code change**: `orchestrate-conclusion-aggregate.sh`'s filter predicate (line
  ~253) changes its coalesce default from `.resolution // ""` to `.resolution // "open"`. This is
  the entire functional fix.
- **Composed tally (lightweight Option 3)**: add a count of how many of the now-classified
  candidates arrived via an implicit null rather than an explicit `"open"`/`"worked_around"`
  value, surfaced alongside the existing `unknown_classes[]` tally in the aggregator's JSON
  output and in Step 6's rendered report. This preserves the provenance signal Option 2's merge
  would otherwise discard, and gives a concrete, measurable basis for revisiting Option 1 later
  if the omission rate stays high after this fix ships.
- **The git-commit-phase.sh "scope excursion" call site needs no change** under this choice
  (unlike under Option 1): it already writes a `null` resolution that will now correctly enter
  classification as `open`, which is arguably more correct for that case (a dropped out-of-scope
  path is a genuinely open finding, not something "fixed inline" by the drop itself).

## Recommendations

1. **Code**: in `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh`
   (source store; redeploy via `deploy-headless.sh` afterward per
   `rules/source-store-deploy-boundary.md`), change line ~253's
   `(.resolution // "") as $r` to `(.resolution // "open") as $r`. Add a new field to the
   `--aggregate` JSON output — e.g. `implicit_open_count` — computed as
   `$candidates | map(select(.resolution == null)) | length`, placed beside
   `unknown_classes`/`no_contribution_tasks` in the final `jq` object.
2. **Docs — `context/formats/issue-log.md`**: update the `resolution` row's Notes column (line
   ~94) to state explicitly: a null/omitted value is treated identically to `"open"` by the
   conclusion stage's filter; there is no way to write a `kind: "issue"` entry that is
   schema-legal yet permanently unreachable.
3. **Docs — `context/contracts/conclusion-stage.md`**: extend "The Filter Predicate" section
   (lines ~50-59) with the same null-equals-open statement, and extend "The Unknown-Class Tally"
   section (or add a new short section) documenting the new `implicit_open_count` field and its
   Step 6 render line.
4. **Docs — `context/patterns/orchestrate-batch-results-template.md`**: add one rendered line in
   the "### Conclusion" block (near the existing "Unknown-class tally" line, ~line 182) for the
   new implicit-open tally.
5. **Docs — `docs/reference/utility-scripts-inventory.md`**: update the one-line descriptions of
   `issue-record.sh` and `orchestrate-conclusion-aggregate.sh` to reflect null's new treatment
   and the new output field.
6. **Tests**: add to `scripts/tests/test-orchestrate-conclusion-aggregate.sh`'s Case (a) (or a
   new adjacent case) a null-`--resolution` `kind: "issue"` entry and assert it now appears in
   `proposals[]`'s citations — directly closing the test-coverage gap identified above, and
   serving as the project's own regression guard for this exact defect going forward.
7. **Regression fixture check**: after the code change lands and is deployed, re-run
   `orchestrate-conclusion-aggregate.sh --aggregate --session <sid> --tasks "739 740"` against
   `~/Projects/BimodalLogic` and confirm three proposals are returned: `class: "tooling"` (3
   citations, task 739), `class: "proof-repair"` (1 citation, task 739), `class: "gate-collision"`
   (2 citations, task 740) — matching this report's Findings table exactly. This is the plan/
   implement phase's concrete acceptance check, not merely a prose restatement of the dispatch's
   acceptance section.
8. **Not recommended for this task**: changing `agent-system/extensions/books/.../signal-tagging.md`'s
   two examples that omit `--resolution`. Under the chosen remedy they are no longer defective
   (the omitted value now correctly enters classification), so touching them would be scope
   creep against this task's file scope; leave as an optional future polish for whoever next
   touches that document.

## Risks & Mitigations

- **Risk**: merging null into `"open"`'s meaning could, in principle, surface more proposals to
  the user than intended if an agent genuinely meant to signal something other than "unresolved."
  **Mitigation**: the fixture-wide empirical check above found zero instances of this in the
  only real data available, and every classified proposal still passes through the existing
  per-channel `AskUserQuestion` approval gate before any action fires — visibility, not
  unilateral action, is the only change in effect.
- **Risk**: the new `implicit_open_count` tally could be read as implying some obligation to act
  on it. **Mitigation**: document it explicitly as informational-only, parallel to
  `unknown_classes[]`'s existing "never a decision this stage makes unilaterally" framing in
  `conclusion-stage.md`.
- **Risk**: a future reviewer might later want Option 1 after all, once agents have had the
  chance to rely on null-as-open. **Mitigation**: the composed tally gives a concrete, measured
  basis (the `implicit_open_count` trend over subsequent invocations) for that future decision,
  rather than requiring a second investigation from scratch.

## Context Extension Recommendations

- **Topic**: class-string drift between what agents actually record and the 15-class seed enum.
- **Gap**: while verifying the fixture, every non-`fixed_inline` class string observed
  (`tooling`, `proof-repair`, `gate-collision` with a hyphen, `verification`, `smooth-execution`,
  `scope-confirmed`, `time-saved`, `tooling leverage`, `task framing`) differs from the nearest
  seed-enum string (e.g. seed `"gate collision"` has a space, the fixture uses
  `"gate-collision"` with a hyphen) — these are silently treated as *different* classes for
  grouping purposes and also populate `unknown_classes[]`. This is a real, observed drift but is
  explicitly out of scope for this task (no change to the three-channel derivation contract) and
  does not block or interact with the null-resolution fix.
- **Recommendation**: a future task could tally real-world `unknown_classes[]` output across
  several `/orchestrate` runs and decide whether any of these near-miss strings are worth
  promoting into `issue-log.md`'s seed enum, per that document's own "Extensibility Rule."

## Appendix

- Search/verification commands used: `grep -rn "issue-record.sh"` /
  `grep -rln "issues\.jsonl"` across `agent-system/extensions/`; direct `cat`/`sed -n` reads of
  `issue-record.sh`, `orchestrate-conclusion-aggregate.sh`, `issue-log.md`,
  `conclusion-stage.md`, `orchestrate-batch-results-template.md`,
  `test-orchestrate-conclusion-aggregate.sh`, `git-commit-phase.sh`, `orchestrate-cycle-postflight.sh`,
  `orchestrate-cycle-plan.sh`, `signal-tagging.md`, `books-observe.sh`, `skill-todo/SKILL.md`,
  `skill-learn/SKILL.md`; direct reads of the two live fixture `issues.jsonl` files under
  `~/Projects/BimodalLogic/specs/archive/`.
- `.claude-extensions.json` confirmed `source_dir` for the `core` extension as
  `agent-system/extensions/core` — the edit target for the plan/implement phase, per
  `rules/source-store-deploy-boundary.md`.
