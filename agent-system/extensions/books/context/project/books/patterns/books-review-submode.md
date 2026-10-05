# Sub-Mode: review

This file is the COMPLETE and ONLY specification for skill-books-review's `--review` sub-mode
execution. It MUST be followed exactly — there is no fuller version of this content anywhere
else. The `### Sub-Mode: review` section of `skill-books-review/SKILL.md` points here via its
stub pointer, which sends an agent here whenever `--review` is dispatched.

A full performance review of the books convention, computed strictly from the accumulated
observation evidence: the digest log, the canonical per-task observation records it points at,
and the RUN log when one exists. Follows the Shared Sub-Mode Skeleton in
`skill-books-review/SKILL.md`, with one sanctioned exemption stated explicitly below.

**Strictly read-only.** `--review` never proposes and never writes, with one sanctioned
exception: its own dated report, named explicitly in Execution: Output below. It never creates a
task, never edits the books convention, and never advances any watermark — `--revise` owns all
three. Any actionable finding this review surfaces is a pointer at `/books --revise`, never an
action taken directly.

## MANDATORY STOP Exemption (Stated, Not Omitted)

Because `--review` does not mutate anything, it needs no `AskUserQuestion` mutation gate. This is
the one sanctioned deviation from the Shared Sub-Mode Skeleton's Interactive Selection
(MANDATORY STOP) step. It is stated here explicitly rather than left as a silent omission: the
absence of a mutation gate is a considered design decision (there is nothing to confirm before
writing, because nothing beyond the dated report is written), not an oversight.

## Edge Case Checks

```
1. Read specs/books-evidence/observations.jsonl.
2. If the file does not exist, or exists with zero lines:
   Display: "No books observation records found yet (specs/books-evidence/observations.jsonl is
   absent or empty). Nothing to review until the books observer has written at least one
   record."
   Return early.
3. For each digest line, attempt to dereference its record_path.
   If a line's record_path does not resolve to a readable file:
   Record it as an unresolvable-pointer finding (named, not silently dropped) and exclude it from
   the per-dimension tables below; continue with the remaining lines. If EVERY line is
   unresolvable:
   Display: "Every digest line's record_path failed to resolve. The digest log exists but no
   canonical observation record could be read. Nothing to review this run."
   Return early.
4. If every resolved record has every one of the seven dimensions unmeasured (see "The Seven
   Dimensions: Per-Dimension Access" below):
   Display: "N observation record(s) were read, but none carries a measured dimension signal yet
   (dimension_signals absent or empty on every record). The report below is produced anyway, with
   every dimension listed under WHAT IS UNMEASURED."
   Continue — this is a degraded report, not an early return; a review that cannot measure
   anything still owes the reader a report naming that fact.
5. If a `burdens_created`/`burdens_lifted` entry names a bearing Decision that resolves to
   NEITHER the `docs/book-convention/` directory shape NOR a remaining flat-index heading (see
   Execution: Burdens Created vs. Burdens Lifted below):
   Report it as a named unresolvable-decision finding in that table row (never a fabricated
   marker) and continue — this, too, is a degraded report, not an early return. Only Check 2's
   and Check 3's all-lines-unresolvable cases return early; a single unresolvable Decision never
   does.
```

## Candidate Identification: The Seven Dimensions, Per-Dimension Access

Every record this sub-mode reads is scored against exactly the seven dimensions defined by
`context/project/books/standards/observation-record.md`, spelled verbatim — **never respell,
abbreviate, or add an eighth**:

| Dimension | Record Field Path | Named Degraded-Behavior String (no data yet) |
|---|---|---|
| `maintainability` | `dimension_signals.maintainability` (by `polarity`) | "`maintainability`: unmeasured — no tagged issues.jsonl entry has reached this dimension yet." |
| `cross_pollination` | `dimension_signals.cross_pollination` (by `polarity`) | "`cross_pollination`: unmeasured — no tagged issues.jsonl entry has reached this dimension yet." |
| `guardrails_qa` | `dimension_signals.guardrails_qa` (by `polarity`) | "`guardrails_qa`: unmeasured — no tagged issues.jsonl entry has reached this dimension yet." |
| `token_cost_efficiency` | `dimension_signals.token_cost_efficiency` (by `polarity`) | "`token_cost_efficiency`: unmeasured — no tagged issues.jsonl entry has reached this dimension yet." |
| `readability` | `dimension_signals.readability` (by `polarity`) | "`readability`: unmeasured — no tagged issues.jsonl entry has reached this dimension yet." |
| `intuitive_exposure` | `dimension_signals.intuitive_exposure` (by `polarity`) | "`intuitive_exposure`: unmeasured — no tagged issues.jsonl entry has reached this dimension yet." |
| `compiling_composing` (plus its two first-class sub-fields `import_weight`, `compilation_weight`) | `dimension_signals.compiling_composing` (by `polarity`); sub-fields never folded into a general performance note | "`compiling_composing`: unmeasured — no tagged issues.jsonl entry has reached this dimension yet. `import_weight`/`compilation_weight`: unmeasured." |

A dimension is counted as measured for a given record only when that record's `dimension_signals`
object carries a non-empty entry for it. A record with no `dimension_signals` group at all (the
whole group is omitted when `issues.jsonl` carried no tagged entries, per the standard)
contributes nothing to any dimension and nothing to `untagged` either — it simply has no signal.

## WHAT IS UNMEASURED (Required, Not Conditional)

Every dimension with zero measured signal across every resolved record is listed BY NAME in a
dedicated `## What Is Unmeasured` section of the output report. **This section is required on
every run, never conditional on there being something to put in it.** A review that silently
omits a dimension it has no data for is worse than one that names the gap — stated as the rule,
not as a style preference. When all seven dimensions have at least one measured signal, the
section still appears, stating "All seven dimensions carry at least one measured signal this
run" rather than being dropped.

`verification_tiers` and `certifier_outcomes` are reported as **absent** wherever the consuming
repository has not built the RUN-log-producing probe, per the Probe Ownership Boundary in
`standards/observation-record.md` — never synthesized. The same applies to `snapshot_delta`
(literal `"absent"` string) whenever no `books/tool/book-snapshot.sh` ran. These three are named
in the WHAT IS UNMEASURED section exactly as the records report them, never inferred or
fabricated by this sub-mode.

## Execution: Signal Reporting — Figures and Trends, Not Adjectives

Per dimension, report positive and negative signal **counts**, by `polarity` (exactly `positive`
or `negative`, no default and no third value), plus a trend across the resolved records ordered
by `recorded_at` (e.g. "3 positive / 1 negative across 4 tasks, most recent: positive"). Signals
with no dimension tag are counted separately as `untagged` and are **never defaulted onto a
dimension they were not actually tagged with** — `untagged_count` is reported as its own figure,
not folded into any of the seven rows.

```
## Signal Summary (figures, not adjectives)

| Dimension | Positive | Negative | Trend |
|---|---|---|---|
| maintainability | {n_pos} | {n_neg} | {trend} |
| ... (all seven, in the order above) |

Untagged signals this run: {untagged_count}
```

## Execution: Cost Per Task and Per Phase Kind

Aggregated across every resolved record's `generic` join group
(`dispatch_count`, `phases`, `outcomes`, `wall_clock_seconds_total`):

```
## Cost (captured at postflight, not live telemetry)

Reflecting only what was captured at each task's postflight — see the caveat below.

| Task | Dispatch count | Phases completed/total | Outcomes | Wall-clock (s) |
|---|---|---|---|---|
| {task} | {dispatch_count or "omitted (metrics_present: false)"} | {phases.completed}/{phases.total} | {outcomes tally} | {wall_clock_seconds_total} |

Totals across {N} tasks: {sum of dispatch_count}, {sum of wall_clock_seconds_total}.
```

**Required capture-time caveat** (state in these terms, every run): these figures reflect what
was captured at each task's own postflight, not live telemetry read now. This mirrors
`context/formats/dispatch-metrics.md`'s own "CAPTURE ONLY — No Reporting Here" framing: that
document states the metrics record "produces the record only" and that "any reporting,
aggregation, dashboard, or cross-task rollup ... is a separate, later concern" — this review IS
that separate, later concern, consuming the record rather than reproducing it live. It is also
bounded the same way `context/project/memory/telemetry-guardrails.md`'s Tier 4 describes for
transcripts: evidence this old may already have rolled out of any live replay window, so a figure
reported here is permanently fixed at whatever each task's postflight measured, not re-verifiable
against a live session once that window has passed.

## Execution: Recurring Issue Classes, Ranked

Read from each resolved record's `generic.issue_counts.by_class` (present only when
`generic.issues_present` is true). Aggregate counts for the same class across every resolved
record, then rank descending:

```
## Recurring Issue Classes (ranked)

1. {class} — {total_count} occurrences across {task_count} tasks
2. ...
```

A class absent from every record's `by_class` is never listed with a fabricated `0` — it simply
does not appear in the ranking (see Omit-Never-Zero below).

## Execution: Burdens Created vs. Burdens Lifted (Paired)

`burdens_created[]` and `burdens_lifted[]` are both always present on every canonical record,
defaulting to `[]`, never one without the other — per the standard's "Paired Burdens" section.
Report them paired, by bearing Decision (durable heading text, e.g. `"Decision 13: Exposure
policy"`):

**Live-marker step (an addition — this sub-mode has no prior step that reads the decision record
directly; `convention_decision` strings come purely from `issues.jsonl` tags today).** For each
bearing Decision named on a `burdens_created`/`burdens_lifted` entry, read the live decision
record using the same enumeration rule as `--revise`'s Mandatory Preliminary Research Step
(`patterns/books-revise-submode.md`): the `docs/book-convention/NN-slug.md` directory shape
first, the flat `docs/book-convention.md` index second. Carry into the table row:

- the Decision's current `- **Validated by**:` **one-line reduced marker**, verbatim (including
  its `→ full exercise history and citations:` pointer where one is present), and
- the paired evidence file path, `docs/book-convention-evidence/NN-slug.md`, read off that
  pointer.

If the named Decision resolves to **neither** shape, report it as a named unresolvable-decision
finding in that row — never a fabricated marker — per the Omit-Never-Zero rule below and Edge
Case Check 5 above.

```
## Burdens: Created vs. Lifted

| Convention Decision | Live Marker | Evidence Path | Burdens Created | Burdens Lifted | Net |
|---|---|---|---|---|---|
| {convention_decision or "(no bearing Decision named)"} | {verbatim reduced marker, or "(unresolvable — neither shape found)"} | {docs/book-convention-evidence/NN-slug.md path, or "--" when unresolvable} | {description list} | {description list} | {created_count - lifted_count} |

Asymmetric Decisions (created without a matching lift) are the strongest `--revise` candidates —
see Funnel Rule below.
```

## Execution: Omit-Never-Zero (D5)

A figure this sub-mode cannot derive is **omitted from the report entirely** — never rendered as
a fabricated `0`. The literal string `"absent"` is used only for the two fields the standard
names that way (`vacuous_passes`, `snapshot_delta`); every other underivable figure is simply left
out of its table row rather than zeroed. `verification_tiers`/`certifier_outcomes` follow the
Probe Ownership Boundary rule above: reported as absent where no probe exists, never synthesized.

**Vacuous passes are first-class and never inferred.** `vacuous_passes` is read verbatim from
each record (either an array of `{tier, detail, source}` entries, or the literal string
`"absent"`) and reported as its own line in the report. This sub-mode never computes a vacuous
pass by negating an ordinary pass — if a record's `vacuous_passes` is `"absent"`, the report says
exactly that, not "none observed."

## Dry-Run

`--dry-run` is an accepted no-op for `--review`: since the sub-mode never writes anything beyond
its own report regardless of this flag, there is nothing a dry run would additionally suppress.
`--dry-run` is accepted (for CLI consistency with `--revise`) and silently has no effect beyond
the normal read-only report.

## Execution: Output

A dated report is written under the consuming repository's `specs/` tree, at
`specs/books-evidence/reviews/{YYYYMMDD}-books-review.md` (ISO-date-prefixed, so repeated runs on
the same day are distinguishable by a `-N` suffix starting at `-2` on collision), containing every
section above in order: Signal Summary, What Is Unmeasured, Cost, Recurring Issue Classes,
Burdens, and the Funnel section below. A terminal summary (the same content, condensed) is also
printed. **This report is the sub-mode's only write.**

The report header carries the pinned `convention_version` (from `manifest.json`;
"unversioned" when unset) and the non-blocking preflight comparison's verdict against the
consuming repository's own `- **Convention version**:` line (match, mismatch, or absent — see
`context/project/books/README.md`'s "Convention version pin and staleness comparison" section
for the full procedure, referenced here rather than restated):

```
Convention version (pinned): {convention_version}
Comparison against the record: {match | mismatch — the record wins, this corpus is stale | absent — the record is unversioned}
```

## Funnel Rule (Explicit Closing Section)

The report closes with a named `## Strongest Candidates for /books --revise` section: the
Decisions with the largest created-without-lifted-match asymmetry, the dimensions with the
highest ranked recurring-issue-class counts, and any unresolvable-pointer or all-unmeasured
finding from Edge Case Checks. The closing line reads, verbatim in spirit: "Run `/books --revise`
to turn these into reviewed research-and-revision proposals." **`--review` performs none of
`--revise`'s follow-on actions itself and proposes no task of any kind** — this is restated here
because it is the single most important behavioral boundary between the two sub-modes.

## Log Entry

Optional and lightweight: `--review` MAY log a `review` operation to a sub-mode-local log
(`specs/books-evidence/review-log.json`, mirroring `.memory/distill-log.json`'s shape with
`pre_metrics` and `post_metrics` identical, matching the general Distill Log Schema's existing
read-only convention for `report`-equivalent sub-modes), recording the report path and the digest
lines consulted, for audit purposes only. This is not required for the sub-mode to function.
