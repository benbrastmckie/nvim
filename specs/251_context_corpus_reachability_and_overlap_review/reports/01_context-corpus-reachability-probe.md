# Research Report: Context-Corpus Reachability Probe

**Task**: Context-corpus reachability probe (filename, directory, index.json), then act on dead
and overlapping files — Phase 1/2 research
**Started**: 2026-10-12
**Completed**: 2026-10-12
**Effort**: large (standing probe + telemetry cross-check; Phase 3 action deferred to the plan)
**Dependencies**: core-agent-system dependency chain (eager-context budget split, task.md slimming,
routing-ladder collapse) — all treated as landing before Phase 3 acts, per the dispatch's own
"measure before they land is stale on arrival" reasoning
**Sources/Inputs**: Codebase exploration of `agent-system/extensions/**` (the source store);
`scripts/script-inventory.sh`, `scripts/assess-repo-health.sh`, `scripts/measure-eager-context.sh`,
`scripts/validate-wiring.sh`, `scripts/validate-index.sh`; `context/architecture/context-layers.md`;
`context/patterns/context-discovery.md`; `context/schemas/events-schema.json`;
`agent-system/extensions/memory/context/project/memory/telemetry-guardrails.md`; a reproduction of
the dispatch's own naive basename-grep orphan check, re-run live against the current tree
**Artifacts**: specs/251_context_corpus_reachability_and_overlap_review/reports/01_context-corpus-reachability-probe.md
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md,
no-task-references-in-deliverables.md

## Executive Summary

- **The corpus has grown again — re-measure confirmed necessary.** The dispatch's 2026-09-22
  figure (523 files, 3,583,550 B) is stale: the current count is **591 `.md` files under
  `agent-system/extensions/**/context/**`, totaling 4,677,170 bytes** — a 13% file-count increase
  and a 30.5% byte increase in under three weeks. Phase 1's probe IS the re-measurement; do not
  carry either number forward as ground truth.
- **The naive-orphan finding is reproducible AND has grown — a second extension library hits the
  exact same false-positive shape.** Re-running the dispatch's own basename-grep check live
  (search for each candidate file's basename anywhere outside a `context/` path) returns
  **39 files with no outside-context referrer today — up from implicitly 39 at the original
  measurement too, but the composition has shifted**: the original 16 present-extension
  `talk/contents/**` templates are still all present, but a SECOND extension,
  `founder/context/project/founder/deck/contents/**` (23 files, directory-referenced by
  `founder/agents/deck-builder-agent.md` and `founder/agents/deck-planner-agent.md` exactly as
  `talk/contents/` is referenced by the present agents), now makes up the other 23. **All 39 are
  false positives under the same reference-style-2 (directory reference) mechanism** — confirmed
  live by grepping both extensions' agent files for their respective `contents/` subdirectory
  names. The Phase 1 regression fixture should assert all 39 current files reachable, not only
  the originally-cited 16 — the dispatch's own number is already an undercount of its own
  fixture.
- **Two sub-flavors of "not referenced from outside context/" exist, and the probe must
  distinguish them, not collapse them into one "false positive" bucket.** The present-extension
  16 are referenced by directory from AGENT files and have **zero textual mention of their own
  basename anywhere in the repo** — true directory-only reachability. The founder-extension 23
  are ALSO referenced by directory from agent files, but their basenames DO appear elsewhere —
  inside `founder/context/project/founder/patterns/slidev-deck-template.md`, itself a context
  file, which lists example import paths by filename. Both groups are reachable (directory style
  from outside context/), but only the present 16 are reachable *exclusively* by the directory
  style; distinguishing "reachable, and by which style(s)" per the dispatch's own per-file field
  design naturally captures both without conflating them.
- **`index-entries.json` is per-extension in the source store (22 files, 577 entries total today)
  — there is no single merged `index.json` to read until deploy time.** A probe reading the
  source store for reference-style-3 reachability must enumerate every
  `agent-system/extensions/*/index-entries.json` and treat an entry's `path` (plus a non-empty
  `load_when`, or `always: true`) as a style-3 reachability hit for that extension's own
  `context/project/<ext>/...` tree. `validate-index.sh` (the existing orphaned-entry checker) only
  reads the already-merged **deployed** `.claude/context/index.json` — it is a different tool
  solving a different question (is this index entry itself ever loaded) and cannot be pointed at
  the source store as-is; the new probe must not assume it can be reused unmodified for this task.
- **Phase 2's telemetry question has a clean, evidence-backed answer: NO, load events are not
  recorded at context-file granularity today, and that is a legitimate finding, not a gap in this
  research.** `events.jsonl`'s schema (`context/schemas/events-schema.json`) has no
  `event_type` for a context-file read anywhere in the corpus — the only `event_type` values
  observed in use are `lifecycle_stage`, `deviation`, `blocker`, and `system_defect`, none of
  which carries a per-file path. `history.jsonl` is prompt-level only (Tier 3 in
  `telemetry-guardrails.md`'s four-tier model) and `.meta.json`/transcript sidecars (Tier 4) are a
  30-day replay window with no outcome or path field either. The only place a context-file read
  is observable at all is inside a live session's own transcript as a `Read` tool-use record — not
  structured telemetry, and gone once the transcript rolls out of its retention window.
  Instrumentation that WOULD close this gap: a new `PostToolUse` hook matched on `Read` (and
  possibly `Bash` for `cat`/`sed -n` reads), filtering for a path under
  `agent-system/extensions/*/context/**` or `.claude/context/**`, appending a new
  `event_type: "context_file_read"` row to `events.jsonl` with the path in `detail`. This repo
  already has `PostToolUse` hook infrastructure (`merge-sources/settings-hooks.json`) and an
  open, extensible `event_type`/`detail` schema that accepts this without a schema change — but no
  such hook exists today, and building it is new scope beyond this task's declared `file_scope`
  (the probe, its test, and the inventory doc only).
- **The eager/lazy axis is almost certainly a trivial "0 eager, 591 lazy" today, and that is the
  correct, expected answer, not a bug in a future probe that reports it.**
  `measure-eager-context.sh`'s own header states its `at_import` channel currently resolves **0**
  references anywhere in the parent-chain/predicted-CLAUDE.md chain — no `@`-ref exists in that
  chain at all. Since context-corpus files only ever enter eager scope via that same `@`-import
  channel (they are never inlined into `CLAUDE.md` any other way), the new probe's per-file
  eager/lazy classifier should currently report every one of the 591 files as `lazy`. Acceptance
  criterion 3 ("the eager/lazy classification agrees with `measure-eager-context.sh`'s totals")
  is satisfied trivially today (0 == 0) but the per-file field must still be built against the
  real channel model so a future added `@`-ref is caught, not merely hardcoded to always answer
  "lazy".
- `script-inventory.sh` (task-adjacent precedent, same author intent: "a standing, mechanical
  inventory probe... following the EXISTING convention of `assess-repo-health.sh` and
  `measure-eager-context.sh`") is the single closest template to copy structurally: `--root`
  override, `--check` mode printing a table and exiting non-zero on a declared finding class,
  default mode emitting one full JSON document, `jq -n`/`--slurpfile` for large per-file arrays,
  a `trap`-cleaned scratch-file discipline, and a documented composite `score`/`rank` so any
  future decomposition target is chosen by evidence. The new context probe should follow this
  shape directly rather than re-deriving conventions `measure-eager-context.sh` alone does not
  fully cover (it has no notion of "candidate enumeration," "per-candidate ranking," or
  "manifest-registration cross-check" — those are `script-inventory.sh`'s contributions, needed
  here too).

## Context & Scope

This is the **research phase only** for the task described in the dispatch. The dispatch's own
Phase 1 (build the probe), Phase 2 (telemetry cross-check), and Phase 3 (act on the ranking) are
all implementation work; this report's job is to re-verify the dispatch's measurements (both are
stale, confirmed above), locate the exact existing scripts/conventions Phase 1 must reuse rather
than reimplement, resolve the structural question of where reference-style-3 data actually lives
in the SOURCE STORE (a question the dispatch does not fully answer — it says "via index.json"
without noting the source store has 22 separate index-entries.json files, not one), and answer
Phase 2's telemetry-granularity question definitively so the plan does not have to re-derive it.
Per the dispatch's own scope discipline, this report does not propose a Phase-3 deletion/merge
list — no file should be named as a removal/merge target before Phase 1's probe exists and has
run; this report only identifies which concrete files are now confirmed-reachable (the regression
fixture) and which codebase conventions constrain the probe's design.

## Findings

### Codebase Patterns

**Corpus re-measurement (this report, 2026-10-12).**
```
find agent-system/extensions -path "*/context/*" -iname "*.md" -type f | wc -l   # 591
find agent-system/extensions -path "*/context/*" -iname "*.md" -type f \
  -exec wc -c {} + | tail -1                                                      # 4,677,170 B
```
Compared to the dispatch's cited 523 files / 3,583,550 B (2026-09-22), this is +68 files (+13.0%)
and +1,093,620 bytes (+30.5%) in under three weeks — byte growth outpacing file-count growth,
consistent with new files tending to be denser/larger rather than many small additions.

**Reproduction of the naive orphan check (this report, 2026-10-12).** For every one of the 591
candidate files, searching the whole `agent-system/extensions/**` tree for the candidate's own
basename as a literal substring (`grep -rlF`), excluding the candidate's own matches and
excluding any referrer whose own path contains `/context/`, returns **39 files with zero
outside-context referrer**:
- 16 under `present/context/project/present/talk/contents/**` (7 subdirectories: `title`,
  `motivation`, `methods`, `results`, `discussion`, `conclusions`, `acknowledgments`) — the exact
  set the dispatch names, confirmed still present and still zero-referenced BY BASENAME anywhere.
  Directly confirmed reachable by directory reference: `present/agents/slides-research-agent.md`
  and `present/agents/slidev-assembly-agent.md` both enumerate `talk/contents/title/`,
  `talk/contents/motivation/`, `talk/contents/methods/`, `talk/contents/results/`,
  `talk/contents/discussion/`, `talk/contents/conclusions/`, and
  `talk/contents/acknowledgments/` by directory path, each covering every file inside.
- 23 under `founder/context/project/founder/deck/contents/**` (8 subdirectories: `appendix`,
  `ask`, `business-model`, `closing`, `cover`, `market`, `problem`, `solution`, `team`,
  `traction`, `why-us-now` — 11 subdirectories, 23 files). Directly confirmed reachable by
  directory reference: `founder/agents/deck-builder-agent.md` and
  `founder/agents/deck-planner-agent.md` both reference `.context/deck/contents/` (and, in
  `deck-builder-agent.md`, the more specific `.context/deck/contents/{path}` template-expansion
  form) repeatedly, and `founder/context/project/founder/patterns/slidev-deck-template.md` shows
  concrete worked examples naming specific files (`closing/closing-standard.md`,
  `traction/traction-metrics.md`) by path — which is why these 23, unlike the present 16, DO
  register at least one basename hit when the search is not restricted to outside-context
  referrers: that one hit lives inside a `context/` file (`slidev-deck-template.md`), so it
  disappears once the search is correctly scoped to "outside context/" — exactly reproducing why
  the dispatch's original check flagged these as orphans too.
- **A path-prefix wrinkle worth flagging for Phase 1's design, not for an agent-prose fix in this
  task**: `founder/manifest.json`'s `merge_targets` deploys `founder`'s context under
  `.claude/context/project/founder/...` — the SAME deploy convention `present` uses
  (`.claude/context/project/present/...`). But `deck-builder-agent.md` and
  `deck-planner-agent.md` both write the directory reference as `.context/deck/contents/...`
  (the **Project Context** layer prefix, a different, user-owned, loader-untouched directory per
  `context-layers.md`), not `.claude/context/project/founder/deck/contents/...` (where the files
  actually land) or a bare `deck/contents/...` (the convention `present`'s agents use). A
  directory-reference reachability check that matches literally on the deployed-relative suffix
  (`deck/contents/<subdir>/`) still finds the hit regardless of this prefix inconsistency — this
  report verified reachability on exactly that basis — but a probe author should not be surprised
  to find the founder agents' literal `.context/` prefix does not match the files' real deployed
  location; it is a pre-existing prose quirk in `founder`'s own agent files, out of this task's
  `file_scope`, and not itself evidence of unreachability.

**Existing conventions Phase 1 must reuse, by field.**

| Dispatch requirement | Existing precedent to reuse |
|---|---|
| JSON-to-stdout, `--check` mode, no side effects, `--root` override, source-store-only | `scripts/script-inventory.sh` (closest: same task-class precedent, explicit header citing "the EXISTING convention of `assess-repo-health.sh` and `measure-eager-context.sh`") |
| Candidate enumeration via `git ls-files` with a `find` fallback for non-git fixtures | `script-inventory.sh`'s `enumerate_candidates()` — directly portable, swap the glob from `**/*.sh` to `**/context/**/*.md` |
| Eager vs. lazy classification, reusing the channel model rather than building a second one | `scripts/measure-eager-context.sh`'s four channels (`parent_chain`, `claudemd`, `at_import`, `rules`) — per the dispatch's own instruction. A context file is eager **only** if it is the resolution target of an `at_import` channel hit; today that channel resolves 0 refs repo-wide, so the correct answer for all 591 files is `lazy` (see Executive Summary) |
| Inbound reference count / single-referrer visibility | `script-inventory.sh`'s `inbound_callers`/`inbound_caller_paths` pattern (`grep -rlFZ` over the basename, OVER-counting by design, never under-counting) — the same caveat applies here: a textual match is not a verified call site, and a reader using the count to justify a merge/removal must open the listed referrer paths |
| Reference style 3 (index.json enumeration) | **Not `validate-index.sh`** (reads only the already-merged deployed `.claude/context/index.json`, and only checks whether an index ENTRY is itself orphaned by `load_when`, not whether a FILE is reachable via the index at all). The new probe must instead glob `agent-system/extensions/*/index-entries.json` directly (22 files today, 577 entries total) and, for each extension's own tree, treat a listed `path` with a non-empty `load_when` (or `always: true`) as a style-3 hit scoped to that extension's `context/project/<ext>/` subtree |
| Reference style 2 (directory reference) | No existing script implements this; this report's live reproduction (above) is the first mechanical check. Treat a referrer's mention of any **prefix directory** of a candidate's path (not just its immediate parent) as a style-2 hit, since both confirmed cases reference at a `contents/<subdir>/` depth, one directory above the leaf file |
| Reference style 1 (filename) | `script-inventory.sh`'s basename-grep IS this style already, correctly implemented; reuse verbatim |
| Manifest/doc registration for the new probe itself | `docs/reference/utility-scripts-inventory.md`'s existing bullet-per-script format (confirmed: one bullet per probe, cross-referencing coexisting siblings e.g. `measure-eager-context.sh` / `measure-eager-surface.sh`'s "coexist, neither supersedes" framing — the new probe's entry should state its own relationship to `script-inventory.sh` the same way, since the two are now siblings covering the two different corpora `scripts/**` vs. `context/**`) |
| Test fixture shape | `scripts/tests/test-script-inventory.sh`'s case list (enumeration, size metrics, caller counting, degenerate-root, usage-error, no-side-effects) is a directly portable template; add a dedicated present/founder-shaped directory-reference fixture case and an index-entries.json style-3 fixture case, since `script-inventory.sh` has neither (the script corpus has no directory-reference or index-registration reachability style at all) |
| Auto-discovery by `run-all.sh` | Confirmed: `run-all.sh` globs `scripts/tests/test-*.sh` per extension — a new `scripts/tests/test-context-inventory.sh` requires no separate registration to be picked up |

**Telemetry tiers (Phase 2), confirmed from primary sources.** `telemetry-guardrails.md`'s
four-tier model: Tier 1 (Claude Code OTel) is outcome-only, no file-path concept at all. Tier 2
(`events.jsonl`, schema at `context/schemas/events-schema.json`) has an open `event_type` string
and an open `detail` object — structurally ABLE to carry a context-file path, but no existing
call site does; a corpus-wide grep for `event_type` literals in use returned only
`lifecycle_stage`, `deviation`, `blocker`, and `system_defect`. Tier 3 (`history.jsonl`) is
prompt-level only (`display`, `timestamp`, `project`, `sessionId` — no tool-call detail at all).
Tier 4 (transcripts/`.meta.json` sidecars) is the only tier that could show a `Read` tool-use
against a context path, but only for 30 days and only by parsing raw transcript JSON, not via any
structured query this repo already has. Conclusion: **context-file-load telemetry does not exist
at file granularity today, on any tier** — this is the legitimate Phase 2 finding the dispatch
explicitly asks for, not a research gap.

### External Resources

Not applicable — this is a purely internal convention/tooling question with no external
precedent to consult; no web research was performed (Stage 2's task-type routing default,
codebase-pattern-first, applies with no secondary web step needed here).

## Decisions

- **Treat 39 (not 16) as the current regression-fixture floor.** The dispatch's own
  "reachable-by-directory, prove all N reachable" acceptance bar is reframed from the stale 16 to
  the live 39: 16 present-extension files plus 23 founder-extension files, both confirmed
  reachable by directory reference from outside `context/` (documented above). The founder 23 are
  additionally reachable by a within-context filename mention — the probe should record BOTH
  hits rather than reporting only the first style found, so the per-file "reachable by WHICH
  style(s)" field the dispatch specifies is populated completely, not short-circuited at the
  first match.
- **The new probe reads per-extension `index-entries.json` files directly, never
  `validate-index.sh` or a merged `index.json`.** `validate-index.sh` answers a different
  question (is this already-deployed index entry itself orphaned) and operates on the wrong tree
  (deployed, not source store) for this task's purpose. No file in this repo today merges all 22
  `index-entries.json` files except the deploy-time loader itself; the probe must do its own
  22-file enumeration.
- **The eager/lazy field is built against `measure-eager-context.sh`'s real `at_import` channel
  model, not hardcoded to `lazy`.** The expected v1 output (591 lazy, 0 eager) is a consequence
  of the channel currently resolving zero refs, not a design shortcut; building the classifier
  against the real channel keeps acceptance criterion 3 true by construction if a future
  `@`-ref into `context/**` is ever added.
- **Phase 2's answer is recorded as a finding, not pursued as new instrumentation in this task.**
  Building the `PostToolUse`-on-`Read` hook identified above as the gap-closing instrumentation is
  explicitly out of this task's declared `file_scope` (the probe, its test, and the inventory doc
  only) and is named here as a candidate follow-up, not as Phase 1/2 work to add silently.

## Recommendations

1. **Build `scripts/context-inventory.sh` as `script-inventory.sh`'s structural sibling**, not a
   divergent design: same `--root`/`--check` flag vocabulary, same `jq -n`/`--slurpfile`
   large-array pattern, same `trap`-cleaned scratch-file discipline, same composite
   `score`/`rank` philosophy (size-dominant, with reachability/eagerness findings as small
   modifiers rather than competing primary signals, mirroring `script-inventory.sh`'s own
   explicit correction of an earlier over-weighted draft).
2. **Enumerate candidates via `git ls-files -- 'agent-system/extensions/**/context/**/*.md'`**
   with the same non-git `find` fallback `script-inventory.sh` already has, for fixture
   compatibility.
3. **Compute reachability as three independent boolean checks, unioned, not short-circuited**:
   (a) basename-grep outside `context/` (style 1, reusing `script-inventory.sh`'s exact
   mechanism); (b) any referrer outside `context/` mentioning a prefix directory of the
   candidate's path, at any depth (style 2, new — this report's live reproduction is the
   reference implementation to adapt); (c) membership in any `agent-system/extensions/*/
   index-entries.json` entry with non-empty `load_when` or `always: true`, scoped to that
   extension's own subtree (style 3, new). Record which of the three fired, not just whether any
   fired, per the dispatch's explicit field spec.
4. **Classify eager/lazy by checking membership in `measure-eager-context.sh`'s `at_import`
   resolution set** (today: empty) rather than re-deriving a second heuristic; if that script's
   output format changes, this probe's classifier must track it rather than drift independently,
   per acceptance criterion 3's explicit non-divergence requirement.
5. **Prove the probe against the 39-file regression fixture named in this report** (not the
   stale 16), asserting each of the 39 reports `reachable: true` with the correct style(s)
   recorded, before registering the probe or touching any Phase-3 deletion candidate.
6. **Register in `docs/reference/utility-scripts-inventory.md`** using the existing bullet
   format, explicitly naming its coexistence relationship to `script-inventory.sh` (same corpus
   class — "a standing, mechanical inventory probe" — different target: `context/**` vs.
   `scripts/**`) the way the file already does for `measure-eager-context.sh` /
   `measure-eager-surface.sh`.
7. **State the Phase 2 instrumentation gap explicitly in the plan/summary rather than building
   it**: name the `PostToolUse`-on-`Read` hook design from this report's Findings as the concrete
   follow-up, scoped out of this task.
8. **Do not expand `file_scope` to any Phase-3 removal/merge target in the plan until Phase 1's
   probe has actually run** against the live tree and produced a ranked, verdict-bearing output —
   this report deliberately proposes zero deletion or merge candidates, per the dispatch's own
   "do not open this task by deleting anything" instruction and its Phase 3 gating.

## Risks & Mitigations

- **Risk**: a future reachability probe short-circuits at the first matching style and under-
  reports which styles actually apply (losing exactly the nuance that distinguishes the present-16
  from the founder-23 in this report). **Mitigation**: compute and record all three style checks
  unconditionally per file, as Recommendation 3 states, rather than stopping at the first hit.
- **Risk**: the probe is pointed at the deployed `.claude/` tree by accident (e.g., a default
  `--root` resolution bug, or reusing `validate-index.sh`'s merged-index assumption), silently
  reading stale or already-regenerated content instead of the source store. **Mitigation**: copy
  `script-inventory.sh`'s `--root` resolution exactly (git-toplevel default, explicit
  `--root` override required for fixtures), and add a test case asserting the probe never opens
  any path under `.claude/` even when run from inside a deployed checkout.
  (`source-store-deploy-boundary.md` applies directly.)
- **Risk**: treating the current "0 eager context files" result as evidence the eager/lazy field
  is a no-op and simplifying it away, which would silently stop catching a future `@`-import into
  `context/**`. **Mitigation**: Decision above — build against the real channel, not a hardcoded
  constant, specifically so this risk cannot materialize invisibly.
- **Risk**: a Phase-3 reader treats this probe's `inbound_callers`-style counts (once built) as
  proof of safety to delete, the same over-trust `script-inventory.sh`'s own header explicitly
  warns against for its textual, OVER-counting-never-under-counting callers field. **Mitigation**:
  carry the identical warning language into the new probe's header and into any Phase-3 removal
  justification, requiring the listed referrer paths to be opened and confirmed, not merely
  counted.

## Context Extension Recommendations

- **Topic**: reference-style-2 (directory reference) reachability has no existing documentation
  anywhere in `context/patterns/` or `context/architecture/` today — `context-discovery.md` and
  `context-layers.md` both describe filename (`@`-import, index `path`) resolution in depth but
  never mention that an agent/skill prose reference to a directory covers its entire subtree.
  **Gap**: a future contributor adding a new template-library extension (a third `.../contents/**`
  style directory, following `present`/`founder`) has no written guidance that directory-style
  references are a sanctioned, recognized reachability mechanism rather than an accidental gap.
  **Recommendation**: once Phase 1's probe exists and is registered, add a short subsection to
  `context/patterns/context-discovery.md` naming directory-reference as a third, equally valid
  reachability mechanism alongside filename and index.json, pointing at the new probe as the
  mechanical check — this is new-doc work appropriately scoped to this task's own Phase 1/3
  landing, not a separate task.

## Appendix

**Search/verification commands used** (all run against the live source-store tree,
2026-10-12):
```bash
find agent-system/extensions -path "*/context/*" -iname "*.md" -type f | wc -l
find agent-system/extensions -path "*/context/*" -iname "*.md" -type f -exec wc -c {} + | tail -1
# Per-candidate basename search excluding self and excluding any /context/ referrer:
grep -rlF -- "<basename>" agent-system/extensions | grep -v '/context/'
grep -rn "talk/contents" agent-system/extensions/present/agents/*.md
grep -rn "deck/contents" agent-system/extensions/founder/agents/*.md
find agent-system/extensions -iname "index-entries.json" | wc -l   # 22
for f in $(find agent-system/extensions -iname "index-entries.json"); do jq '.entries|length' "$f"; done  # sums to 577
grep -rho 'event_type[":= ]*"\?[a-z_]*' agent-system/extensions/core | sort -u
```

**References**:
- `agent-system/extensions/core/scripts/script-inventory.sh`
- `agent-system/extensions/core/scripts/measure-eager-context.sh`
- `agent-system/extensions/core/scripts/validate-wiring.sh`
- `agent-system/extensions/core/scripts/validate-index.sh`
- `agent-system/extensions/core/context/architecture/context-layers.md`
- `agent-system/extensions/core/context/patterns/context-discovery.md`
- `agent-system/extensions/core/context/schemas/events-schema.json`
- `agent-system/extensions/memory/context/project/memory/telemetry-guardrails.md`
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`
- `agent-system/extensions/present/agents/slides-research-agent.md`,
  `agent-system/extensions/present/agents/slidev-assembly-agent.md`
- `agent-system/extensions/founder/agents/deck-builder-agent.md`,
  `agent-system/extensions/founder/agents/deck-planner-agent.md`,
  `agent-system/extensions/founder/context/project/founder/patterns/slidev-deck-template.md`
- Prior task's research report (closest precedent for a corpus-wide inventory probe; cited by
  pattern only, not by task number, per `no-task-references-in-deliverables.md`):
  `specs/archive/250_script_corpus_inventory_and_engine_decomposition/reports/01_script-corpus-inventory-probe-and-decomposition.md`
