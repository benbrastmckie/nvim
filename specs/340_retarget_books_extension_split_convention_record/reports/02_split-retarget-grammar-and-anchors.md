# Research Report: Task #340

- **Task**: 340 - Retarget the books extension to the split convention record and pin the convention version
- **Started**: 2026-10-05
- **Completed**: 2026-10-05
- **Effort**: 1-2 working days (confirms the seed report's estimate)
- **Dependencies**: none hard
- **Sources/Inputs**:
  - `agent-system/extensions/books/scripts/books-observe.sh` (lines 1-60 header, 100-170 awk/helpers, 280-520 `observe_run_core`)
  - `agent-system/extensions/books/scripts/tests/test-books-observe.sh` (Case 1 "THE JOIN" fixture, lines 1-220)
  - `agent-system/extensions/books/context/project/books/patterns/books-revise-submode.md` (Edge Case Checks, Mandatory Preliminary Research Step)
  - `agent-system/extensions/books/context/project/books/patterns/books-review-submode.md` (Edge Case Checks, Candidate Identification, Burdens section)
  - `agent-system/extensions/books/context/project/books/standards/observation-record.md`
  - `agent-system/extensions/books/context/project/books/README.md`, `tools/tooling-inventory.md`, `domain/known-gap-register.md`
  - `agent-system/extensions/books/context/project/books/standards/metadata-split.md`, `domain/book-toml-v2.md`, `domain/certificate-ledger-and-records.md`, `domain/identity-and-versioning.md`, `domain/layer-vocabulary-and-matrix.md`, `domain/status-and-trust-vocabularies.md`
  - `agent-system/extensions/books/manifest.json`, `agent-system/extensions/core/scripts/check-extension-docs.sh`
  - Consuming repository (`~/Projects/Logos/Verification`, live filesystem read, not modified): `books/scripts/lint-validated-by.sh` (lines 1-250, 420-480), `docs/book-convention.md`, `docs/book-convention/*.md` (all 18), `docs/book-convention-evidence/README.md` and `13-exposure-policy.md`, `docs/architecture-decisions.md`, `docs/fault-frame-design.md`, `.claude-extensions.json`, `specs/books-evidence/` (absent), current HEAD (`a07ae5f`, dated 2026-10-05)
- **Artifacts**: this report
- **Standards**: report-format.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Executive Summary

- The seed report's measured breakage is confirmed line-for-line against the live `books-observe.sh` (flat `validated_by_files` string at what is now a slightly later line than the seed cited, single `^## Decision` awk regex) and the live `test-books-observe.sh` fixture (flat `## Decision 13` shape, Case 1).
- The consuming repository's reference grammar is confirmed verbatim in `lint-validated-by.sh:206-210` (the `RECORD_HEADING_RE` table) and `:216-241` (`DIR_HEADING_RE='^# Decision [0-9]+[[:space:]]*:'`, `expand_dir_shape()`, unconditional flat-path scan). **One correction to the dispatch's own rendering**: the reduced marker's pointer arrow is the Unicode character `→` (U+2192), not the ASCII `->` the dispatch text displays — confirmed in `docs/book-convention/13-exposure-policy.md:4` and `lint-validated-by.sh`'s own in-code citation. The fault-frame heading dash is similarly the Unicode em dash `—` (U+2014), and `lint-validated-by.sh`'s own `fault-frame-design.md` regex already encodes this as `(—|-)`, not `(--|-)`. Any new regex this task writes must match on these literal Unicode characters, not their ASCII look-alikes.
- **A measurement correction to the seed report, not a new defect**: re-deriving the known-gap-register.md census directly from all 18 live `docs/book-convention/*.md` marker lines today gives **2 binding (Decisions 5, 14), 15 `partially`, 1 `none yet` (Decision 18)** — i.e. exactly the **2/15/1** our own `known-gap-register.md:31` already states, not the "**1/15/2**" the seed report/dispatch describes as the record's current truth. The register's only confirmed staleness is its dated git SHA (`7281c81`) and date (2026-10-03) against the live HEAD (`a07ae5f`, 2026-10-05); its census figures do not need correcting. The implementer should re-verify the census mechanically (per the register's own "How to refresh this file" section) rather than overwrite 2/15/1 with 1/15/2 on the dispatch's say-so.
- `books/tool/book-snapshot.sh` **does not exist** in the consuming repository (`books/tool/` has no such file; confirmed by directory listing). This is not a defect to fix: `books-observe.sh`'s own snapshot-probe branch already guards with `[ -x "$snapshot_probe" ]` and falls through to the documented `"absent"` sentinel, exactly the Probe Ownership Boundary (D3) the standard already describes. The task's "confirm the snapshot probe name and contract" acceptance item is satisfied by recording this absence, not by any code change.
- The six anchor citations all resolve cleanly to single or paired decision files; the mapping is given below so the plan phase can write the six retargets directly rather than re-deriving them.
- No `books` entry exists in the consuming repository's `.claude-extensions.json`, and `specs/books-evidence/` does not exist there — the seed report's deployment-status claim is reconfirmed, unchanged, as of this HEAD.

## Context & Scope

Research scope: verify the seed report's every factual claim against current line numbers and content (both repos may have moved since the seed was written), extract the exact reference grammar to copy, resolve the six anchor citations to concrete target files, and determine where the `convention_version` pin should live given `check-extension-docs.sh`'s actual validation surface. Out of scope (per the dispatch's Scope Boundary): writing any code, designing the phased plan, or touching `.claude/**`.

## Findings

### Observer: current line numbers and exact strings

`agent-system/extensions/books/scripts/books-observe.sh`:
- Line ~131-135 (inside `extract_validated_by_pairs`, around line 130): `awk '/^## Decision/ { heading = $0; ... } /^- \*\*Validated by\*\*:/ { if (heading != "") print heading "\t" $0 }'` — a single regex applied identically to every file passed to it.
- Line ~311 (inside `observe_run_core`, the "BOOKS FACT 2" block): `local validated_by_promotions=() validated_by_files="docs/book-convention.md docs/architecture-decisions.md docs/fault-frame-design.md"` — confirmed flat, confirmed hard-coded to exactly these three paths, confirmed no directory-shape handling.
- Promotion detection (`before_map`/`after_content` diff) compares the **entire** marker line as a string (`$prev != $a_marker`), not a value-prefix-only comparison — confirmed this is the mechanism the dispatch's "PROMOTION DETECTION compares the marker's VALUE PREFIX ONLY" requirement must change: today, an edit to only the evidence-pointer tail (the `→ full exercise history...` clause) WOULD be misread as a promotion, because the comparison has no prefix-stripping at all yet. `lint-validated-by.sh`'s own `strip_marker_prefix()` (`sed -E 's/^- \*\*Validated by\*\*: ?//'`) returns the whole value including the pointer; the dispatch's "value prefix only" cut point is **before** the ` → full exercise history` text specifically, which neither script currently implements — this is new logic to add, not an existing helper to reuse. A straightforward implementation: strip the marker label (as `strip_marker_prefix` does), then additionally cut at the first occurrence of ` → full exercise history` (or, for backward compatibility with the flat-only files that carry no pointer at all, no cut occurs and the whole value is compared).
- Snapshot probe reference (`local snapshot_probe="${repo_root}/books/tool/book-snapshot.sh"`) and its `--diff "$before_ref" "$last_commit" --json` invocation are confirmed exactly as the dispatch states; the probe itself is simply absent in the one consuming repository checked.
- `schema_version: "observation-v1"` is confirmed unchanged.

### Test fixture: confirmed false green

`scripts/tests/test-books-observe.sh` Case 1 ("THE JOIN", roughly lines 96-130) writes:
```
cat > "$repo1/docs/book-convention.md" <<'EOF'
## Decision 13: Exposure policy
- **Validated by**: none yet
EOF
```
then promotes it via `sed -i 's/none yet/partially, see xyz/'` and asserts `validated_by_promotions.entries[0].decision == "Decision 13: Exposure policy"`. This is exactly the obsolete flat `## Decision N` shape with no evidence pointer at all — it cannot fail against the current observer no matter how badly the real record has drifted, which is why it has stayed green through the split.

### Reference grammar to copy (consuming repo, `books/scripts/lint-validated-by.sh`)

Confirmed verbatim:
```bash
declare -A RECORD_HEADING_RE=(
  ["book-convention.md"]='^## Decision [0-9]+[[:space:]]*:'
  ["architecture-decisions.md"]='^## Decision [0-9]+[[:space:]]*:'
  ["fault-frame-design.md"]='^### Decision [0-9]+[[:space:]]*(—|-)'
)
GOVERNED_BASENAMES_ORDER=("book-convention.md" "architecture-decisions.md" "fault-frame-design.md")
DIR_HEADING_RE='^# Decision [0-9]+[[:space:]]*:'
DIR_RECORD_LOGICAL_BASE="book-convention.md"
DIR_RECORD_DIRNAME="book-convention"
```
`expand_dir_shape()` lists `"$dirpath"/*.md` sorted (plain `sort`, which is lexicographic but the files are already zero-padded `01-...` through `18-...` so lexicographic equals numeric here), appending to three parallel arrays. The flat path is **always** scanned in addition to the directory, unconditionally — pre-, mid-, and post-migration all fall out of one unconditional check, matching the dispatch's "FLAT FILE ALWAYS SCANNED" instruction exactly. A decision present in both shapes at once (the transitional state) is treated as a **duplicate-marker finding** by the lint (CHECK 1's cross-shape dedup block, confirmed around line 450), not silently deduplicated — the new observer fixture for "transitional flat-plus-directory record" should decide, and state explicitly, whether the observer mirrors this duplicate-finding behavior or just unions both (the dispatch does not specify; this is a planning decision, not a research gap, since the observer's `before_map`/`after_content` diff mechanism is structurally different from the lint's one-pass-per-key accumulation and will need its own answer either way).

`strip_marker_prefix()` is `sed -E 's/^- \*\*Validated by\*\*: ?//'` — label-only stripping, reusable verbatim for the "value" half; the additional pointer-text cut described above is this task's own new addition, cited by path to `lint-validated-by.sh` per the dispatch's "cite it by path in the script header" instruction, but not literally present in that script as a separate function (`lint-validated-by.sh` has no need to strip the pointer, since it unions the evidence-pair citations rather than diffing before/after).

### The reduced marker's exact literal shape

From `docs/book-convention-evidence/README.md`'s own "Reduced marker template (Ruling 3)":
```
- **Validated by**: <value> — <one clause naming the most recent instance> → full exercise
  history and citations: [docs/book-convention-evidence/NN-slug.md](../book-convention-evidence/NN-slug.md)
```
Confirmed byte-for-byte in a live file (`docs/book-convention/13-exposure-policy.md:4`), using `→` (U+2192 RIGHTWARDS ARROW), not `->`. The en/em dash before "full exercise history" region of the template uses an ASCII `—` em dash as a clause separator within `<value>` itself (not load-bearing for the cut point); the load-bearing cut point for "value prefix only" is the literal substring `→ full exercise history and citations:`.

### Sub-mode fixes: confirmed structure, Edge Case numbering

`books-revise-submode.md`'s Edge Case Checks are numbered 1-4; **Edge Case 4** (the dispatch's own numbering) is confirmed to be "Attempt to read the consuming repository's `docs/book-convention.md`. If it cannot be found: ... Return early — this is a HARD early return." This needs no renumbering — only its body needs to become shape-tolerant (fires only when *neither* the flat file nor the `docs/book-convention/` directory exists), per the dispatch.

The "Mandatory Preliminary Research Step" (same file, below "Candidate Identification") is where the per-candidate verbatim-marker/durable-heading capture lives today, reading only the flat file; this is the one concrete edit site for revise.

`books-review-submode.md`, by contrast, has **no existing step that reads `docs/book-convention.md` directly today** — its "Burdens: Created vs. Lifted" table sources `convention_decision` strings purely from already-written `issues.jsonl` tags on the observation record, never from a live read of the convention file. The dispatch's instruction to give "the review sub-mode's research step ... the same treatment" therefore means **adding** a comparable verbatim-marker-quoting step to review (most naturally alongside its Burdens section, so the reported Decision names can carry their live marker/evidence-pointer rather than only the durable heading string), not editing an existing one. The report-header convention-version line is a separate, simpler addition to the "Execution: Output" section's dated-report template.

### The six anchors, resolved to concrete targets

All six confirmed present at the cited lines in the current corpus (none has drifted since the seed report); each resolves to exactly one or two decision files via the consuming repo's live `docs/book-convention/*.md` numbering:

| Corpus file:line | Cites | Resolves to |
|---|---|---|
| `standards/metadata-split.md:4` | Decision 6 (`:610-798`) | `docs/book-convention/06-where-metadata-lives.md` |
| `domain/book-toml-v2.md:8` | Decision 7 (`:799-906`) | `docs/book-convention/07-book-toml-v2-schema.md` |
| `domain/certificate-ledger-and-records.md:8` | Decisions 8 (`:907-1092`), 9, 11 | `docs/book-convention/08-computed-dependencies-and-book-cert-json.md`, `09-trust-unit-is-the-export.md`, `11-versioning-rule.md` |
| `domain/identity-and-versioning.md:9` | Decision 9 (`:1093-1213`) and Decision 11 (`:1367-1497`) | `docs/book-convention/09-trust-unit-is-the-export.md` and `11-versioning-rule.md` |
| `domain/layer-vocabulary-and-matrix.md:7-8` | Decision 2 (`:245-326`) and Decision 3 (`:327-424`) | `docs/book-convention/02-layer-vocabulary.md` and `03-layer-import-matrix.md` |
| `domain/status-and-trust-vocabularies.md:7` | Decision 12 (`:1498-1575`) | `docs/book-convention/12-status-vocabulary-and-trust-block.md` |

Retarget form: drop the `:LINE-RANGE` suffix entirely and cite the decision file path (optionally plus "Decision N" by name, which every one of these six already does in prose alongside the line-range parenthetical) — the line range is the only part the split invalidates.

### Figure refresh: exact current values

- `docs/book-convention.md` (consuming repo, now the slim index): **343 lines** (was 3,212 before the split) — `README.md:10`'s "3,212 lines" is confirmed stale and needs both a new figure and a note that it is now the slim index, not the full record.
- Decision count: still **eighteen** — `README.md:6,10,26` and `tooling-inventory.md:134`'s "eighteen" figures need no change.
- `known-gap-register.md:31`'s "**Marker census, measured 2026-10-03**: ... two binding ... fifteen `partially` ... one `none yet`" is **confirmed still accurate** today (2 binding = Decisions 5, 14; 15 partial; 1 none-yet = Decision 18) — see the Executive Summary correction above. Only the dated git SHA (`7281c81` → current HEAD `a07ae5f`, dated 2026-10-05) and the "Measured as of 2026-10-03" date are stale and need bumping; the census numbers themselves do not.
- `tooling-inventory.md:134`'s "`docs/book-convention.md`'s eighteen `Validated by` markers" prose is accurate in count but should be updated to name the directory-plus-index shape, since the markers no longer all live in one file.

### `convention_version` pin placement

`check-extension-docs.sh` (`agent-system/extensions/core/scripts/`) has no schema that restricts manifest.json to a fixed top-level key set — its checks (`check_manifest_entries`, `check_routing_block`, `check_undeclared_skills/rules/scripts`, etc.) all walk specific known keys (`provides.*`, `routing_agents*`, `observers`) and never reject an unrecognized sibling key. Adding a new top-level `"convention_version"` / `"measured_at_commit"` pair to `agent-system/extensions/books/manifest.json` is therefore safe and will not trip any existing gate. `check_line_count_accuracy` (the only figure-accuracy check in the file) validates `index-entries.json`'s `line_count` against each context file's actual `wc -l`, which is unrelated to this pin and imposes no constraint on it. Recommendation for the plan phase: put the structured `convention_version`/`measured_at_commit` pair in `manifest.json` (machine-readable, trivially greppable by the preflight comparison script) and mirror it as prose in `context/project/books/README.md`'s existing normative-record paragraph (human-readable, keeps the "where the two disagree, the record wins" framing visible at the one entry point).

### Preflight comparison: no hook exists, and must not gain one

`manifest.json`'s `"hooks": []` is confirmed empty, and the dispatch is explicit that it must stay that way. The two sub-mode skills' SKILL.md files each have a documented Stage 2 ("Preflight Status Update") that currently only touches generic task-status plumbing (`skill-preflight-flow.md`), not books-specific content — this is the natural, hook-free integration point for the "read the record's `- **Convention version**:` line, compare once, report mismatch/absence non-blockingly" step the dispatch describes for `/books`-topic research/implementation dispatches. Because `docs/book-convention.md`'s "Convention version" line does not exist yet in the consuming repository (confirmed: no match for "onvention version" anywhere under `docs/` or `books/`), the "absent line means unversioned" branch is the one that will fire on every comparison until the consuming repository's own forthcoming Decision 19 lands (referenced only in this repo's own task-hold metadata, not yet in the live corpus) — this is expected, not a bug to chase.

## Decisions

- Treat the dispatch's `->`/`--` ASCII renderings of the pointer arrow and fault-frame dash as transcription artifacts of the task description's own markdown, not the literal bytes to match; all new regex/string logic must use the real `→` (U+2192) and `—` (U+2014) characters confirmed above.
- Do not change `known-gap-register.md`'s census numbers (2/15/1 is correct); only its dated SHA/date need bumping, following the file's own "How to refresh this file" section.
- Treat `books/tool/book-snapshot.sh`'s absence as confirmed-and-expected, not a defect; no code change is implied by the "confirm the snapshot probe name and contract" acceptance item beyond recording this finding.
- Recommend `manifest.json` top-level fields for the `convention_version`/`measured_at_commit` pin, mirrored as README prose, since `check-extension-docs.sh` imposes no schema conflict either way.
- The value-prefix-only promotion comparison (cutting at `→ full exercise history and citations:`) is new logic neither existing script implements today; it is not a reuse of `lint-validated-by.sh`'s `strip_marker_prefix`, only a cousin of it.

## Recommendations

1. Phase 1 (observer + fixtures): replace the flat `validated_by_files` string with the per-record heading-regex table above (copied verbatim, cited by path to `lint-validated-by.sh`); add directory-expansion by numeric-prefix sort; add the value-prefix-only promotion comparison cutting at the literal `→ full exercise history and citations:` string; add the four new fixtures (directory-shaped, transitional flat+directory, fault-frame `### Decision N —` heading, pointer-only-edit-must-not-count); decide and state explicitly how the observer treats a transitional duplicate marker (mirror the lint's duplicate-finding, or union silently) since the dispatch leaves this open.
2. Phase 2 (sub-mode patterns): edit `books-revise-submode.md`'s Mandatory Preliminary Research Step and Edge Case 4 to be shape-tolerant per the six-row table above's model; **add** (not edit) a comparable verbatim-marker step to `books-review-submode.md`'s Burdens section, plus a convention-version line in its report-header template.
3. Phase 3 (anchors + figures): retarget the six anchors per the resolved-target table above (drop line ranges, keep Decision-N prose); refresh `README.md:10` (343 lines, slim index), `tooling-inventory.md:134`, and `known-gap-register.md:3` (SHA + date only, not the census).
4. Phase 4 (pin + preflight): add `convention_version`/`measured_at_commit` to `manifest.json` plus `standards/observation-record.md`'s field table (optional field) and the README mirror; wire the non-blocking, hook-free preflight comparison into both sub-mode SKILL.md Stage 2 sections (and, since `/books --review`/`--revise` also run outside research/implement dispatch, into those two sub-mode files' own Edge Case Checks), reporting "record wins, corpus stale" on mismatch and "unversioned" on the (currently universal, since Decision 19 does not exist yet) absent-line case, each exactly once per run.
5. Gate with `verify-deploy.sh`, `check-extension-docs.sh`, `check-task-references.sh`, and all three `scripts/tests/test-books-*.sh` suites, per the dispatch's Acceptance section.

## Context Extension Recommendations

- **Topic**: none. This is a correctness retarget of existing extension content against an external repository's already-documented layout; no new context-architecture gap was found.

## Appendix

- Searches: direct `grep -n`/`sed -n` reads of every file named in the dispatch and seed report, in both `~/.config/nvim/agent-system/extensions/books/` and `~/Projects/Logos/Verification/`; no web search was needed (purely local, cross-repository verification task).
- Verified absent: `~/Projects/Logos/Verification/books/tool/book-snapshot.sh`; any "Convention version"/"convention_version" string anywhere under that repo's `docs/`/`books/`; a `books` key in that repo's `.claude-extensions.json`; `specs/books-evidence/` in that repo.
- Verified present and unchanged since the seed report: all six anchor line citations, the false-green fixture, the flat `validated_by_files` hard-coding, the single-regex heading lookback.
