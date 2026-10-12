# Ranked Disposition: Context-Corpus Reachability Probe

Evidence source: `probe-run.json` (two consecutive live-tree runs, byte-identical modulo
`generated_at`; `candidate_count: 591`, `total_bytes: 4,686,806`, `zero_reference_count: 0`,
`eager_count: 0`, `lazy_count: 591`).

**Telemetry verdict** (Phase 2/3 of the dispatch): no telemetry tier in this repo records a
context-file read at file granularity today. `specs/events.jsonl`'s `event_type` set observed in
use (`artifact_auto_repair`, `artifact_write`, `error_logged`, `lifecycle_stage`,
`malformed_postflight_marker`, `orchestrator_status`, `push_grant_consumed`,
`push_grant_issued`, `session_stop`, `subagent_stop`, `system_defect`) carries no path-level,
tool-call event; the memory extension's `history.jsonl` is prompt-level, not file-level. Every
verdict below is therefore **STATIC reachability only** ("could this be loaded"), never
confirmation of observed use ("has this been loaded"). Closing that gap would require a
`PostToolUse` hook on `Read`/file-reading `Bash` forms, filtering paths under
`agent-system/extensions/*/context/**`, appending an `event_type: "context_file_read"` row to
`events.jsonl` — the existing open `event_type`/`detail` schema accepts this without a schema
change. Building that instrumentation is explicitly out of this task's scope.

## 1. Confirmed Dead

**Count: 0.** Every one of the 591 candidates reports `reachable: true` by at least one of the
three independent styles. This matches the research report's conclusion exactly: the naive
basename-only check's 39 apparent orphans (16 present-extension slide templates, 23
founder-extension deck templates) are false positives, each covered by the `directory` style (a
bare reference to an ancestor directory, covering the whole subtree transitively) and, for all
23 founder files plus all 16 present files, also by `filename` (both template libraries'
basenames appear verbatim in their own extension's `index.json`/pattern files or README tree
listing).

No file in this corpus fails ALL THREE checks. There is nothing to remove.

## 2. Single-Referrer / Inline Candidates

**Count: 56** files report `inbound_references == 1`. Per the probe's own METHOD WARNING,
`inbound_references` is a textual, deliberately OVER-counting proxy — a single hit is evidence a
reader must open and confirm, never proof of safety to inline, and a LOW count is not itself a
defect: a file reachable only through its own extension's `index-entries.json` registration is
operating exactly as the index-loading mechanism (Style 3) is designed to work.

**54 of the 56** are referenced solely by their own extension's `index-entries.json` (the
file's own index registration, not a second prose mention). This is the EXPECTED steady state for
most of this corpus's on-demand files — `index-entries.json` with a populated `load_when` is
*how* a lazily-loaded file is reachable at all, not a sign of under-use. No inlining is
recommended for this group; opening each one to disposition it individually is not merited by a
"1" that means "found exactly where the loader convention says to look."

**2 of the 56** are referenced by a single AGENT file rather than their own index entry:

| Path | Sole referrer |
|---|---|
| `agent-system/extensions/founder/context/project/founder/domain/legal-reasoning-patterns.md` | `agent-system/extensions/founder/agents/legal-analysis-agent.md` |
| `agent-system/extensions/founder/context/project/founder/patterns/financial-analysis-forcing-questions.md` | `agent-system/extensions/founder/agents/financial-analysis-agent.md` |

Both are domain-specific reference material consumed by exactly one specialized agent each —
consistent with a narrow, single-purpose domain file, not evidence of redundancy or
under-reachability. **Recommendation: no action.** A single dedicated consumer is the normal
shape for a domain-specific pattern/reference file; inlining either into its one agent would
trade a reusable, independently-versioned context file for agent-prose bloat, which is the
opposite direction from this corpus's own stated budget concerns.

## 3. Substantial-Overlap Candidates

**No mechanical overlap/duplicate-content detector was built in this task** (the plan's own
Non-Goals explicitly excludes "a general clone/near-duplicate detector" — `context-reachability.sh`
computes reachability and eager/lazy classification only, never a content-similarity signal). This
section therefore reports a lightweight MANUAL scan, not a probe verdict, and is clearly
distinguished as such.

The one mechanical signal available — duplicate BASENAMES across different extensions — surfaces
18 filenames repeated across two or more extensions (e.g. `README.md`, `validation.md`,
`compilation-guide.md`, `testing-patterns.md`, `theorem-environments.md`, `proof-conventions.md`,
and others). A spot check of three of these pairs by line count shows each pair is a GENUINE
naming-convention collision, not duplicated content:

| Basename | Instance A (lines) | Instance B (lines) |
|---|---|---|
| `validation.md` | `core/context/validation.md` (46) | `core/context/orchestration/validation.md` (715) |
| `compilation-guide.md` | `latex/.../tools/compilation-guide.md` (256) | `typst/.../tools/compilation-guide.md` (63) |
| `testing-patterns.md` | `python/.../patterns/testing-patterns.md` (123) | `nvim/.../standards/testing-patterns.md` (238) |

Each pair's line counts differ substantially, consistent with independently-authored,
domain-specific content that happens to share a conventional filename (every extension
maintaining its own `README.md`-shaped reference file), not a near-duplicate pair. **No merge
candidates are recommended from this scan.** A dedicated near-duplicate content detector (the
Non-Goal this task deliberately excluded) is the correct tool to answer this question with real
evidence rather than a filename coincidence, and is named here as a legitimate candidate for a
future, separately-scoped task if overlap is ever suspected on stronger grounds.

## 4. Live-but-Oversized

Ranked by bytes (top 10 of 591, all currently `lazy`, none `eager`):

| Rank | Bytes | Path | Rule-or-command → lazy-narrative split applicable? |
|---|---|---|---|
| 1 | 168,381 | `core/context/patterns/batch-orchestration-guardrails.md` | No — already a `context/patterns/` file, not a `rules/*.md` command/rule source; the split pattern applies to a rule-or-command file with an eager-loaded narrative, not to an already-lazy pattern doc |
| 2 | 100,730 | `core/context/patterns/task-lock.md` | No — same reason as above |
| 3 | 55,082 | `core/context/patterns/regeneration-is-manual-only.md` | No — same reason |
| 4 | 54,715 | `core/context/standards/orchestrator-runtime-files.md` | No — a `context/standards/` file, already the lazy-narrative TARGET shape, not a rule/command source |
| 5 | 52,670 | `core/context/standards/git-staging-scope.md` | No — same reason |
| 6 | 49,556 | `core/context/formats/plan-format.md` | No — a `context/formats/` reference file, already lazily loaded |
| 7 | 48,289 | `core/context/patterns/system-defect-discrimination.md` | No — same reason as rank 1-3 |
| 8 | 44,470 | `core/context/formats/return-metadata-file.md` | No — same reason as rank 6 |
| 9 | 43,617 | `core/context/reference/state-management-schema.md` | No — a `context/reference/` file, already lazy |
| 10 | 31,623 | `core/context/standards/status-markers.md` | No — same reason as rank 4-5 |

**None of the top 10 (or, by inspection of the distribution, any file in this corpus) is a
`rules/*.md` or `commands/*.md` source file with an EAGER-loaded narrative still embedded in
it** — the rule-or-command → lazy-narrative split this task's Phase 3 was chartered to
generalize (the `git-workflow.md` → `git-workflow-narrative.md` exemplar) applies to a file that
is itself loaded eagerly (a rule matched by `paths:` against most sessions, or a command file) and
carries reference material that does not need to be eager. Every file in this corpus is already
`lazy` (`eager_count: 0` — confirmed in Section "Telemetry verdict" context above and by direct
diff against `measure-eager-context.sh`'s own `at_import` set in Phase 3). **The split this task
was chartered to generalize has no live target in this corpus**: the split pattern consumes an
EAGER rule/command file as its input, and this corpus has none. A large LAZY file's size is a
reader-attention cost when it IS loaded, not a session-start budget cost — a different, narrower
problem than the one the split pattern solves. No split is recommended for the top 10 (or, on the
same reasoning, for any other candidate) on the evidence gathered here.

## Decision Gate

**Branch taken: confirmed-dead set is EMPTY** (Section 1, count 0) — the expected outcome per the
plan's Scope Hypothesis. No file was removed, no pair was merged, and no rule-or-command split
was applied. This phase's removal/merge/split sub-steps are closed via `#### Reasoned Exclusions`
below rather than left open, since the evidence needed to decide them is now fully gathered and
the decision in every case is "no action."

#### Reasoned Exclusions

| Item | Reason | Evidence |
|---|---|---|
| Remove confirmed-dead files | Zero candidates qualify | `probe-run.json`: 591/591 files report `reachable: true`; `zero_reference_count: 0` in `summary` |
| Merge substantial-overlap pairs | No mechanical overlap signal exists (Non-Goal), and the one available proxy (duplicate basenames) is confirmed by spot check to be a naming convention, not duplicated content | Section 3 above: 3 of 18 duplicate-basename pairs spot-checked by line count, all substantially different lengths |
| Apply rule-or-command → lazy-narrative split | The split's INPUT shape (an eager rule/command file with an embedded narrative) has zero live instances in this corpus | `probe-run.json`: `eager_count: 0`, cross-checked against `measure-eager-context.sh --check`'s own empty `at_import` set in Phase 3 |

## References

- `probe-run.json` — the cited live probe output (two reproducible runs)
- `context-reachability.sh` — the probe itself, registered in
  `docs/reference/utility-scripts-inventory.md`
