# Research Report: Task #423

**Task**: 423 - Fix verify-deploy context budget byte-count drift
**Started**: 2026-11-10T20:30:00Z
**Completed**: 2026-11-10T20:58:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/core/scripts/measure-eager-context.sh, verify-deploy.sh, orchestrator-context-budget.json), git history (per-file blob diff against commit c75de9179, the "task 417 phase 3" commit that last recorded a reviewed eager-load measurement), live re-run of the regression test suite
**Artifacts**: - specs/423_fix_verify_deploy_context_budget_byte_count_drift/reports/01_eager-budget-overage-attribution.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Live re-measurement (2026-11-10, this session): `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check` (run from repo root) reports **TOTAL: 68,606 B**, 1,806 B over the current `eager_load.baseline_bytes` of 66,800 B. `test-verify-deploy-context-budget.sh` reproduces the same 2-of-13-case failure the task description cites (baseline-fixture-not-clean + unsafe-pad-amount), confirmed live via `run-all.sh --only test-verify-deploy-context-budget.sh`.
- Diffing the full eager-set file-by-file against the last reviewed measurement commit (`c75de9179`, "task 417 phase 3", 2026-10-18, 65,312 B measured / 66,800 B baseline, 1,488 B headroom) attributes essentially all of the 3,294 B growth to six specific files, none of which carry redistributable restatement duplication on inspection.
- **Recommendation: route (b)** — a reviewed, dated `eager_load.baseline_bytes` move, appended to the config's own `note` field, per the established precedent (2026-10-09 `/approve` entry: a brand-new extension's floor cost, once already compressed to a minimal pointer-style structure, has no further slack to redistribute). No route (a) (trim-and-relocate) candidate was found in the content that actually grew since 2026-10-18 — see Findings for the per-file audit. Re-measure immediately before making the move; the figures above will have drifted further by implementation time (per the dispatch's own warning and this report's own 18 B observed drift against the dispatch file's same-day 2026-11-10 figure).

## Context & Scope

The task is to resolve a deterministic (not ambient-host-state-dependent) content-size regression: `agent-system/extensions/core/scripts/measure-eager-context.sh --check`'s eager-loaded-content total has grown past `orchestrator-context-budget.json`'s `eager_load.baseline_bytes`, causing `test-verify-deploy-context-budget.sh` to fail 2 of 13 cases. The config file's own `eager_load.note` field records nine prior resolutions of this same recurring regression, each either (a) a trim-and-relocate of genuinely redistributable bloat into a non-eager-loaded file, or (b) — only when no such slack exists — a reviewed, dated, deliberately modest baseline move with written justification appended to `note`. This research scopes only the attribution/decision question (which route applies and why); it does not perform the fix (that is implementation-phase work) and does not touch `known-failures.txt` (removing that suite's row is correctly scoped to the implement phase, after the fix lands and the suite is re-verified green).

Two findings surfaced by the live suite run are explicitly **out of scope** for this task and are not analyzed further here: `gate5 core: Content differs from source: docs/guides/creating-extensions.md` and a `dead-command-recommendation` lint hit on `/ide` references in two memory-extension context files. Both stem from this repo's deployed `.claude/` tree being stale relative to the source store for the `core` extension (per this dispatch's own `<deploy-freshness-context>` block) and from a pre-existing `/ide` reference, not from the eager-load byte-budget regression this task targets.

## Findings

### Codebase Patterns

- `measure-eager-context.sh`'s `claudemd` channel is the PREDICTED assembled `.claude/CLAUDE.md`: `core/templates/claudemd-header.md` (prepended untrimmed) plus, for every extension listed in `.claude-extensions.json`'s `extensions` object, that extension's own `merge_targets.claudemd.source` file (resolved from its `manifest.json`), each trailing-whitespace-trimmed. Currently active: `approvals`, `core`, `email`, `lean`, `literature`, `memory`, `nix`, `nvim`, `sapience`.
- The `rules` channel sums every rule file under `agent-system/extensions/*/rules/` whose frontmatter `paths:` glob (or absent-frontmatter default) matches at least one of the script's representative touched-path probes (`specs/000_example/reports/01_example.md`, `.claude/context/example.md`) — currently 9 files.
- `parent_chain` is the repo-root `CLAUDE.md` plus the (empty, on this machine) parent `~/.config/CLAUDE.md`.

### External Resources

Not applicable — this is a pure codebase/git-history attribution task with no external dependency.

### Per-File Growth Attribution (2026-10-18 reviewed baseline -> 2026-11-10 live)

Baseline commit used: `c75de9179` ("task 417 phase 3: record the trim and resulting headroom in the budget config", 2026-10-18 01:55:43 -0700) — the commit that landed the config's own last-recorded measurement (65,312 B, 1,488 B headroom under the then-and-still-current 66,800 B `baseline_bytes`).

| File | 2026-10-18 (B) | 2026-11-10 live (B) | Delta (B) |
|---|---|---|---|
| `agent-system/extensions/sapience/EXTENSION.md` | 0 (extension did not exist) | 2,065 | **+2,065** |
| `agent-system/extensions/core/merge-sources/claudemd.md` | 15,432 | 16,166 | +734 |
| `agent-system/extensions/lean/EXTENSION.md` | 2,291 | 2,678 | +387 |
| `agent-system/extensions/literature/merge-sources/claudemd.md` | 4,876 | 4,918 | +42 |
| `agent-system/extensions/memory/EXTENSION.md` | 2,721 | 2,788 | +67 |
| `agent-system/extensions/nix/EXTENSION.md` | 1,385 | 1,401 | +16 |
| `agent-system/extensions/core/rules/source-store-deploy-boundary.md` | 1,588 | 1,570 | -18 |
| All other eager files (parent_chain, remaining rules, remaining `claudemd` sources: `approvals`, `email`, `nvim`, header) | unchanged | unchanged | 0 |

Net: +3,293 B, matching the observed total growth (65,312 -> 68,606 = +3,294 B; the 1 B residual is a trailing-whitespace-trim rounding artifact of the per-fragment trim the script applies, not a missed file).

**What each delta actually is, on inspection of the diff (not just the byte count):**

- **`sapience/EXTENSION.md` (+2,065 B, entirely new).** The `sapience` extension did not exist at the 2026-10-18 baseline; its entire `EXTENSION.md` is new. Read in full: it is already compressed to a minimal orientation form (short paragraphs, each ending in a pointer to a `domain/*.md` file for full depth — `review-gate-boundary.md`, `per-repo-scoping.md`). Spot-checked `review-gate-boundary.md` and `per-repo-scoping.md` (non-eager, 5,058 B and 5,421 B respectively): their content is substantially deeper than and not verbatim-duplicated by the `EXTENSION.md` orientation paragraphs that point to them. This matches the 2026-10-09 `/approve`-extension precedent exactly: a brand-new extension's floor discoverability cost, already at a pointer-only minimum, with nothing left to redistribute.
- **`core/merge-sources/claudemd.md` (+734 B).** Three independent, non-duplicative additions: a `/telemetry` Command Reference row + a `skill-telemetry` Skill-to-Agent Mapping row (both genuinely new commands, task 497); a Hard Mode paragraph rewrite replacing the retired `routing_agents_hard`/4th-`effort_flag` description with the current per-domain `hard_contracts` injection mechanism (task 444's routing-agent retirement) — already pointer-style before and after, describing a changed mechanism rather than adding a restatement; and a two-sentence jq-reflow-hazard note that itself ends in a same-file pointer ("see that same file's ... section"). None of the three restates content already carried in full elsewhere in the eager set.
- **`lean/EXTENSION.md` (+387 B).** Two new one-line Context Pointer bullets (`external-library-dependency-assessment.md`, `plan-authoring-gate-collisions.md`), each already in the file's established bare-pointer-plus-one-clause style — no restatement to trim.
- **`literature/merge-sources/claudemd.md` (+42 B) and `memory/EXTENSION.md` (+67 B) and `nix/EXTENSION.md` (+16 B).** All three are stale-reference correctness fixes (task 435/497-adjacent terminology cleanup replacing retired `/research N` / `/plan N` / `/implement N` separate-command references with the current `/orchestrate`-dispatched-phase language), not new restatable content. The net byte growth is incidental to rewording, not duplication.
- **`rules/source-store-deploy-boundary.md` (-18 B).** Already shrank since the baseline (unrelated prior trim) — contributes negative growth, already working in this task's favor.

No file in the grown set exhibits the shape of the prior route-(a) resolutions (a full section or table verbatim-duplicating a non-eager companion file) — each prior trim (e.g. 2026-10-18's own `artifact-formats.md` Phase Status Markers section, or `memory/EXTENSION.md`'s `/distill` command table) was found by exactly this kind of close read, and this read found none remaining.

## Recommendations

- **Take route (b): a reviewed, dated baseline move.** Append a new dated entry to `orchestrator-context-budget.json`'s `eager_load.note` field (never silently re-derive `baseline_bytes` from the fresh measurement without this entry — the field's own existing warning) stating: the per-file attribution above (sapience extension's full floor cost as a brand-new extension, plus the `core`/`lean`/`literature`/`memory`/`nix` necessary-content additions), that a full audit of the newly-grown content found no further redistributable duplication, and the specific before/after byte figures from a **fresh** re-measurement taken at implementation time (do not reuse this report's 68,606 B figure verbatim — re-run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check` from the repo root immediately before editing, per the dispatch's own re-measure warning and the 18 B of drift this report already observed against the dispatch file's same-day figure).
- Follow the established rounding convention visible in every prior entry: round the fresh measurement up to the next 100 B for the new `baseline_bytes` value (e.g. a fresh measurement of 68,606 B would round to 68,700 B; use whatever the implementation-time fresh measurement actually reads).
- Leave both per-file `ceiling_bytes` entries (`skills/skill-orchestrate/SKILL.md`, `commands/orchestrate.md`) untouched — this task's finding is scoped to `eager_load.baseline_bytes` only, matching every precedent entry's own scoping discipline.
- After the config edit, verify with both commands the dispatch names: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh` and `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check` (both from the repo root).
- Once green, remove the `test-verify-deploy-context-budget.sh` row from `agent-system/extensions/core/scripts/tests/known-failures.txt` (currently line 40, class `real-defect`).
- Do not attempt to fix the two out-of-scope findings surfaced by the live suite run (`gate5` deploy-staleness on `docs/guides/creating-extensions.md`, and the `/ide` dead-command-recommendation lint hit) as part of this task — they are unrelated pre-existing conditions, not part of the eager-load byte-budget regression.

## Decisions

- Confirmed the defect is genuinely a content-growth/baseline regression (deterministic, reproducing identically live), not an ambient-host-state issue, consistent with the originating corpus-triage ledger's classification.
- Selected the last commit that recorded a *reviewed* measurement (`c75de9179`, 2026-10-18) as the diff baseline, rather than the task description's stale 2026-10-09/2026-10-16 figures, since the config's own `note` history shows the baseline and measurement were both deliberately re-set as of 2026-10-18 and nothing in the `note` field was updated since.
- Determined route (b) applies: every byte of growth traced to a specific, already-pointer-style addition or a stale-reference correction, with no remaining verbatim-duplicated content found on inspection.

## Risks & Mitigations

- **Drift between this report's figures and implementation-time figures**: the config's own `note` explicitly warns the total "will drift again with any further eager-set edit," and this report already observed an 18 B drift against the dispatch file's own same-day 2026-11-10 figure (source: a prior, unrelated trim to `rules/source-store-deploy-boundary.md`). Mitigation: the Recommendations section above directs a fresh re-measurement immediately before editing, not reuse of this report's numbers.
- **Concurrent sibling tasks editing the same eager-loaded tree this cycle**: per this dispatch's Territory block, task 461 and task 499 have declared file_scope overlapping parts of `agent-system/extensions/core/` and `agent-system/extensions/sapience/` respectively (directory-granularity for 499, including `agent-system/extensions/memory/` and `agent-system/extensions/sapience/EXTENSION.md` itself). A further concurrent edit to any of those files before this task's implement phase could change the exact overage figure again. Mitigation: the implement-phase dispatch must re-read the territory declarations and re-measure live immediately before editing, consistent with the general concurrency discipline this dispatch's Territory block already states.
- **Rounding too generously**: the established convention rounds up to the next 100 B, not further — a larger round risks masking a genuine future regression for longer. Mitigation: follow the convention exactly; do not round beyond the next 100 B increment.

## Context Extension Recommendations

none

## Appendix

### Search queries / commands used

- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check` (run from repo root) — live total and per-file breakdown.
- `git log --oneline --all -- agent-system/extensions/core/context/config/orchestrator-context-budget.json` — located the last reviewed-measurement commit.
- `git show <commit>:<path> | wc -c` vs. `wc -c <path>` for each active extension's `merge_targets.claudemd.source` file and each of the 9 eager rule files, plus `CLAUDE.md` — per-file delta table above.
- `git diff c75de9179 -- <path>` for each file that showed nonzero delta — confirmed the nature of each addition (new command row, pointer bullet, terminology correction, mechanism-description rewrite) rather than relying on byte counts alone.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh` — live reproduction of the 2-of-13-case failure, plus the two out-of-scope findings noted above.
- `grep -n "verify-deploy-context-budget" agent-system/extensions/core/scripts/tests/known-failures.txt` — located the row to remove once the fix is verified (line 40).

### References

- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — the config holding `eager_load.baseline_bytes` and its full `note` history of prior route (a)/(b) resolutions.
- `agent-system/extensions/core/scripts/measure-eager-context.sh` — the measurement script (predictive; source-store only).
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` — the regression test reproducing the failure.
- `specs/170_isolate_shell_suites_from_host_state/reports/02_corpus-triage-ledger.md` — originating triage ledger that spawned this task and classified the defect.
