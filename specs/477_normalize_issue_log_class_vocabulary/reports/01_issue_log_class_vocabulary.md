# Research Report: Task #477

**Task**: 477 - Normalize issue-log class vocabulary; reject/union the conclusion aggregator's malformed `--tasks` call shape
**Started**: 2026-11-22T00:00:00Z
**Completed**: 2026-11-22T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/core/{scripts,context}), corpus scan of every tracked `issues.jsonl` in this repository (active + archive)
**Artifacts**: - specs/477_normalize_issue_log_class_vocabulary/reports/01_issue_log_class_vocabulary.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **1a (promote `scope excursion`)** is not a judgment call at all: `scope excursion` (lowercase,
  single space, no hyphen) is already the literal `--class` string two independent, mechanical,
  high-volume call sites emit today — `git-commit-phase.sh:741` and `git-commit-scoped.sh:866`.
  Promoting it into `context/formats/issue-log.md`'s seed enum is pure documentation catch-up, with
  zero source-code change needed at either call site.
- A corpus-wide scan of every `issues.jsonl` file tracked in this repository (not just the five
  cited tasks) found **859 distinct raw `class` strings** across roughly 3,800 lines, confirming
  the dispatch's fragmentation claim at far larger scale, and reproducing every near-duplicate pair
  the dispatch named (`COVERAGE_GAP`/`coverage-gap`/`coverage_gap`/`coverage gap`,
  `design-gap`/`design-ambiguity`, the five scope spellings) plus dozens more
  (`gate collision`/`gate-collision`/`gate_collision`; `research-quality`/`research
  quality`/`research_quality`/`RESEARCH_QUALITY`; `verification-gap`/`verification gap`;
  `stale-premise`/`stale premise`; `pre-existing-failure`/`pre-existing failure`).
- The repeated-`--tasks` defect (Part 2) is confirmed exactly as described: the flag parser's
  `case` branch unconditionally overwrites `tasks_arg` on each occurrence, with no accumulation and
  no error. The script's own documented, and only-ever-used, call convention
  (`context/contracts/conclusion-stage.md` Step 1) already passes `--tasks` as a single
  space-joined string (`"${touched_tasks[*]}"`) — there is no existing union convention anywhere in
  this script to justify accepting repeats as a union, which points the decision toward
  rejection.
- No OTHER list-valued flag exists in this script to audit (Part 2b): `--session`, `--channel`,
  `--answer` are all genuinely scalar selectors, where repeat-overwrites-last is the ordinary,
  unsurprising shell-flag convention, not a hazard of the same shape as `--tasks`.
- Promoting any class into the 17-class seed enum touches more files than the two
  authoritative-list files: 8 files reference "17-class"/the seed-enum count in prose and will go
  stale on any promotion (enumerated below).

## Context & Scope

This is a `meta` task editing `agent-system/extensions/core/` (the source store for the `.claude/`
deploy). Two independent defects share one edit target
(`scripts/orchestrate-conclusion-aggregate.sh`) and one regression home
(`scripts/tests/test-orchestrate-conclusion-aggregate.sh`), consolidated into one task per the
Multi-Task Creation Standard's Component 0.

Scope, per the dispatch:
1. Promote a canonical `scope excursion` spelling into the seed enum (1a).
2. Add case+separator folding at grouping time in the aggregator, never rewriting stored `class`
   values (1b).
3. Decide and record how far normalization should go — mechanical fold vs. semantic merge (1c).
4. Address free-text-sentence `class` values (1d).
5. Fix the repeated-`--tasks` silent-last-wins defect, one way or the other (2a).
6. Audit the script's other list-valued flags for the same hazard (2b).

Out of scope (per the dispatch's own territory notes): records 402, 448, 435 claim the same test
file for unrelated defects/sweeps and require serialization within a batch, not a dependency edge;
record 459 is adjacent doctrine, read-only; the issue-log contract's own threading design (closed
record) is not re-litigated.

## Findings

### Codebase Patterns

**The aggregator's grouping has zero normalization today.** In
`scripts/orchestrate-conclusion-aggregate.sh`'s `--aggregate` jq pipeline, candidates are piped
straight into `group_by(.class)` on the raw string (lines 258-285 of the script). `COVERAGE_GAP`
and `coverage-gap` therefore produce two separate proposal groups, each under-citing the true
scope of the recurring class — the exact defect the dispatch describes.

**The repeated-`--tasks` defect is a one-line consequence of the manual `case`/`shift 2` parser.**
Lines 88-100:
```bash
while [ $# -gt 0 ]; do
  case "$1" in
    --aggregate) MODE="aggregate"; shift ;;
    ...
    --tasks) tasks_arg="${2:-}"; shift 2 ;;
    ...
  esac
done
```
Each `--tasks` occurrence unconditionally reassigns `tasks_arg`, so `--tasks 275 --tasks 274`
leaves `tasks_arg="274"` with no diagnostic. The one real call site
(`context/contracts/conclusion-stage.md` line 230-231) already uses the correct single-string form
(`--tasks "${touched_tasks[*]}"`), so the repeated-flag shape that triggered this task was a
caller error against an already-correct, already-documented convention — not a second legitimate
call shape competing with the first.

**jq's `ascii_downcase` is already an established idiom in this codebase** for case-insensitive
comparison (`scripts/lib/task-type-detect.sh:154`, matching a keyword against a task description).
No existing helper performs separator folding (hyphen/underscore/multi-space -> single space) for
`class`-shaped strings; this would be new, and is small enough to inline as a jq `def` inside the
aggregator's own `-s` filter rather than factored into `lib/common.sh` — nothing else in the
codebase needs it today, and premature library extraction for a single consumer is the issue this
codebase elsewhere avoids.

**Promoting a seed class is a multi-file, hand-synchronized operation, not a 3-file one.**
`SEED_CLASSES_JSON` in the aggregator, the `ISSUE_SEED_CLASSES` bash array (plus a comment-only
copy) in `issue-record.sh`, and the authoritative table in `context/formats/issue-log.md` are the
three files holding the actual 17-entry list and each needs the new entry added. Separately, the
numeral "17" (or the phrase "17-class seed enum") is restated in prose, unlisted, in at least 5
more files — found via `grep -rln "17-class\|17 classes\|seed enum" --include="*.md"
--include="*.sh" .` from `agent-system/extensions/core/`:
`context/contracts/conclusion-stage.md`, `context/contracts/phase-closure.md`,
`scripts/orchestrate-build-dispatch.sh` (the literal text injected into every generated dispatch
file's "Issue Log" section — visible verbatim in this very dispatch's own body),
`context/standards/error-recovery-strategies.md`, and
`context/patterns/orchestrate-batch-results-template.md`. All 8 files need to agree once a class is
promoted (17 -> 18); a plan that only touches the 3 list-holding files will leave 5 stale "17"
mentions behind.

**`scope excursion`'s dominance is partly a mechanical-writer artifact, not purely organic
drift.** Sampling the corpus's 443 `scope excursion` entries shows nearly all of them are emitted
automatically by `git-commit-phase.sh`/`git-commit-scoped.sh` whenever a file is dropped from a
scoped-commit pathspec for being outside the task's declared `file_scope` — a mechanical,
guaranteed-identical-spelling writer, not hundreds of independent agent judgment calls. This
doesn't weaken the promotion case (if anything it strengthens it — the spelling can never drift at
those two call sites), but it does mean the "8 occurrences across five tasks in a single
invocation" figure in the dispatch is the *agent-authored* subset of a much larger, already
self-consistent mechanical population.

**Other already-hardcoded classes outside the seed enum exist**, emitted the same mechanically
(never drifting) way: `"source store excursion"` and `"derived-surface staleness"`
(`git-commit-phase.sh`), `"orchestration defect"` (seeded already), `"derived artifact staleness"`,
`"unresolved task-domain blocker"`, `"repository configuration"`, `"milestone ref landing"`
(`orchestrate-cycle-postflight.sh`), `"roadmap regenerate blocked, no approval surface"`
(`orchestrate-conclusion-roadmap.sh`). These are out of this task's named scope (only `scope
excursion` was dispatched for promotion) and are noted here only as an adjacent observation for a
future promotion pass — not acted on.

**Near-duplicate pairs are not uniformly "spelling of the same word."** The dispatch's five scope
spellings are a mix of two different things: pure separator/case noise (`scope-correction` vs.
`scope_correction` vs. `SCOPE_DEVIATION` vs. `scope deviation` — these fold together safely) and
genuinely distinct phrases built from different words (`excursion` vs. `deviation` vs.
`correction` vs. `omission`). Reading a sample of `scope/file_scope omission discovered
pre-emptively` entries shows this one is the *opposite* direction of `scope excursion`: an omission
is scope found to be too *narrow* (something missing was caught proactively), while an excursion is
work falling *outside* a stated scope. Mechanical fold correctly leaves these un-merged (different
words survive folding as different strings); a blanket "all scope-flavored classes merge" rule
would have been wrong, concretely illustrating why 1c's semantic-merge caution is warranted and not
merely a hedge.

### External Resources

Not applicable in any load-bearing way: this is an internal, convention-driven fix to a single
repo-local bash/jq script and its accompanying documentation contract. The authoritative sources
are the already-read `context/formats/issue-log.md` and `context/contracts/conclusion-stage.md`,
not external documentation. (jq's `ascii_downcase`/`gsub` are already in standard use in this
codebase per the Codebase Patterns section above, so no external lookup was needed to confirm their
availability or semantics.)

## Recommendations

**1a — Promote `scope excursion`.** Add it as the 18th seed class in `context/formats/issue-log.md`
with a gloss grounded in the mechanical writer's own usage, e.g.: "A touched file or action fell
outside the task's declared `file_scope`; recorded mechanically by the scoped-commit tooling
(`git-commit-phase.sh`/`git-commit-scoped.sh`) when a file is dropped from a commit pathspec for
this reason, or by an agent noting the same thing by hand." Update, in sync, the three list-holding
files (`issue-log.md`, `issue-record.sh`'s array + comment, the aggregator's `SEED_CLASSES_JSON` +
comment) and the 5 "17-class" prose mentions enumerated in Findings above (8 files total). No
change needed at the two call sites that already emit the exact literal.

**1b — Grouping-time normalization only, never rewriting stored data.** Add a jq `def
normalize_class(c): c | ascii_downcase | gsub("[-_\\s]+"; " ") | gsub("^\\s+|\\s+$"; "")` (or
equivalent) inside the aggregator's existing `-s` pipeline, and change `group_by(.class)` to
`group_by(normalize_class(.class))`. Keep each proposal's displayed `class` field as the raw value
of (for example) the group's first/most-frequent member — never a synthesized or rewritten string —
and keep every `entries_tmp` line, and every on-disk `issues.jsonl` line, byte-identical. This
satisfies the dispatch's HARD CONSTRAINT directly: normalization is a read-time-only
transformation inside one jq filter, with no write path touched.

**1c — The three-part shape, with semantic aliasing deferred, not populated, in this task.**
Recorded as the explicit decision (see Decisions below): ship (i) the mechanical fold unconditionally,
(ii) the alias-table *mechanism* (a small hand-maintained jq object literal in the aggregator,
e.g. `{"design-gap": "design-ambiguity"}`-shaped, consulted after mechanical folding and before
`group_by`), seeded **empty** at this task's completion, and (iii) the existing `unknown_classes[]`
tally re-keyed to run against the post-fold (and post-alias, once populated) normalized value so
that pure spelling noise stops inflating it, while un-aliased semantic near-duplicates still surface
there individually for a human to review and, later, explicitly alias. This defers populating the
table with any of this task's own candidate pairs (design-gap/design-ambiguity; the scope quintet)
to a future, separately-reviewed promotion, matching this document's own
already-established philosophy that the seed enum "grows deliberately... never by drift."

**1d — Warn, don't refuse, on long normalized-length `class` values; document the rest as
convention.** Add a length-based (not verb-keyword-based — see Decisions below) lenient check in
`issue-record.sh`, alongside the existing seed-enum leniency warning: after applying the same fold
used in 1b, count whitespace-separated tokens; above a threshold of 6 (one token above the longest
legitimate seed-class gloss, `cost-forced exclusion or substituted verification`, which folds to 6
tokens), emit a stderr warning and still append — never refuse, matching this script's established
open-enum posture. Pair this with a short style note in `issue-log.md`: "`class` is a short noun
phrase (2-5 words), not a narrated sentence; detail belongs in `what_happened`, not in `class`."
This catches the clearest offender (`reuse-not-reimplement confirmed by direct source read`, 8
tokens post-fold) without flagging the large population of short, idiomatic, verb-bearing classes
already live in the corpus (see Decisions below for why a verb-keyword heuristic was rejected).

**2a — Reject repeated `--tasks`.** Detect repetition in the argument-parsing loop (e.g., a
`tasks_seen` counter incremented on each `--tasks` match) and exit 1 with a usage error naming the
correct single-string form (`--tasks "N N N"`) when `--tasks` appears more than once. This matches
the dispatch's stated safer default and has no competing in-script convention to prefer union
over it.

**2b — Audit result: no other hazard found.** `--session`, `--channel`, and `--answer` are the
only other flags; all three are genuinely scalar (a session id, a closed-enum channel key, a
closed-enum yes/no answer) where "last occurrence wins" is the ordinary, expected shell-flag
behavior, not a silent-misparse hazard of the `--tasks` shape. No change needed for these three.

## Decisions

- **Canonical spelling is `scope excursion`** (lowercase, single space, no hyphen) — not a new
  choice but a ratification of what `git-commit-phase.sh:741` and `git-commit-scoped.sh:866`
  already emit literally, and the corpus's single most frequent class (443 occurrences) by a wide
  margin. No competing spelling of the word "excursion" itself exists anywhere in the scanned
  corpus.
- **Normalization is grouping-time-only, inside the aggregator's jq pipeline; `issues.jsonl` is
  never touched.** This is non-negotiable per the dispatch's HARD CONSTRAINT and is the only design
  consistent with append-only provenance.
- **The alias table ships as an empty, documented mechanism, not pre-populated with this task's
  own candidate semantic merges.** Evidence for each named semantic pair is thin (1 corpus
  occurrence each for `design-gap`/`design-ambiguity`) and at least one scope spelling
  (`scope/file_scope omission discovered pre-emptively`) is plausibly the *opposite* concept from
  `scope excursion`, not a synonym of it. Committing a semantic merge on this evidence risks the
  exact invisible-signal-destruction failure mode the dispatch names; building the mechanism without
  populating it keeps the door open for a future, better-evidenced promotion without re-touching the
  script's structure.
- **1d's detector is length-based (post-fold token count), not keyword/verb-based.** A sample of
  live corpus classes (`hypothesis confirmed`, `fix confirmed working`, `mechanism confirmed`,
  `blocker-cleared`, `tooling worked first try`, `falsifiability confirmed`) shows short,
  verb-bearing class names are already widespread, legitimate, idiomatic usage — a keyword
  blocklist on words like "confirmed"/"found"/"discovered" would false-positive against a large
  share of the existing `kind: "win"` population. Token-count-after-fold is cheap, auditable, and
  does not collide with that population.
- **Both defects stay in one task and one edit target** per the dispatch's own Multi-Task Creation
  Standard Component-0 consolidation note; this report does not re-open that question.

## Risks & Mitigations

- **Risk**: the normalization fold could accidentally merge two classes that happen to be
  case/separator-identical but semantically distinct once the corpus grows. *Mitigation*: the fold
  is restricted to case and separator transforms only — it never merges two strings built from
  different words, which is the actual safety property the dispatch asks for; any future semantic
  worry is handled through the (separately gated) alias table, not the fold.
- **Risk**: adding the 18th seed class without updating all 8 files that mention "17" leaves stale
  prose (including the live dispatch-file template text generated by
  `orchestrate-build-dispatch.sh`). *Mitigation*: the plan should explicitly enumerate and verify
  all 8 files found above, not stop at the three list-holding ones; a grep-based self-check
  (`grep -rn "17-class\|17 classes"` returning empty afterward) is a cheap acceptance gate.
- **Risk**: a length-based 1d warning could false-positive on a legitimate long seed-class-style
  phrase in the future. *Mitigation*: the threshold (6 tokens post-fold) is calibrated to the
  longest existing seed-class gloss, and it is a warning, not a refusal — a legitimate long class
  still gets written, just with a stderr note, consistent with the script's existing leniency
  posture for unknown classes.
- **Risk**: rejecting repeated `--tasks` could itself be a breaking change if some other
  undiscovered call site relies on the old silent-last-wins behavior. *Mitigation*: the only
  documented call site (`conclusion-stage.md` Step 1) already uses the correct single-string form;
  a repo-wide grep for `--tasks.*--tasks` or multiple `--tasks` occurrences in one invocation
  should be run at plan/implementation time as a final check before landing the rejection.

## Context Extension Recommendations

- **Topic**: seed-enum promotion blast radius.
- **Gap**: `context/formats/issue-log.md`'s "Extensibility Rule" documents that promotion is "a
  documentation change... never an enforcement change," but does not name the full set of files a
  promotion must touch (the 8-file list found in this report).
- **Recommendation**: add a short "Promoting a Class" subsection to `issue-log.md` naming the
  3 list-holding files plus a `grep -rln "17-class\|N-class seed enum"` self-check, so the next
  promotion (and this task's own implementation) doesn't have to rediscover this list by hand.

## Appendix

- Search queries/commands used:
  - `grep -o '"class":"[^"]*"' $(find specs -name issues.jsonl) | sort | uniq -c | sort -rn` —
    corpus-wide class frequency scan (859 distinct values, ~3,800 lines).
  - `grep -n -- '--class "' *.sh` in `agent-system/extensions/core/scripts/` — enumerating every
    hardcoded (mechanically-written) `class` literal in the codebase.
  - `grep -rln "17-class\|17 classes\|seed enum" --include="*.md" --include="*.sh" .` from
    `agent-system/extensions/core/` — the promotion blast-radius file list.
  - `jq '.extensions.core.source_dir' .claude-extensions.json` — confirmed source-store edit
    target (`/home/benjamin/.config/nvim/agent-system/extensions/core`).
- Files read in full: `scripts/orchestrate-conclusion-aggregate.sh`,
  `scripts/tests/test-orchestrate-conclusion-aggregate.sh`, `scripts/issue-record.sh` (header +
  validation body), `context/formats/issue-log.md`, `context/contracts/conclusion-stage.md`
  (Steps 1-2, Cross-Task Grouping Rule, Unknown-Class Tally sections).
