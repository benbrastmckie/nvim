# Research Report: Task #323

**Task**: 323 - Declare migrate-state-legacy-fields.sh in core manifest
**Started**: 2026-10-02T21:55:00Z
**Completed**: 2026-10-02T22:00:00Z
**Effort**: Trivial (single JSON array edit + one README refresh touch)
**Dependencies**: None
**Sources/Inputs**: Codebase (manifest.json, check-extension-docs.sh, verify-deploy.sh, README.md, git history), specs/reviews/review-2026-10-02.md, specs/ROADMAP.md
**Artifacts**: - specs/323_declare_migrate_state_legacy_fields_in_core_manifest/reports/01_declare-script-in-manifest.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed, independently and exactly as described in the dispatch: `agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh` (9,914 B, executable, git-tracked) exists on disk but is **absent** from `provides.scripts` in `agent-system/extensions/core/manifest.json` (199 entries currently, alphabetically ordered; the neighboring `migrate-directory-padding.sh` IS present, this one is not).
- `bash .claude/scripts/check-extension-docs.sh` reproduces both findings verbatim: `FAIL: script file on disk NOT in provides.scripts: scripts/migrate-state-legacy-fields.sh` and `WARN: README.md older than manifest.json (possible drift)`.
- The fix is a two-line change: (1) add the one string to `provides.scripts` in manifest.json, (2) touch `README.md` with any substantive edit (its WARN is a pure mtime comparison, not content-based — see Findings).
- README.md does **not** enumerate all 199 scripts by name (it gives a representative sample plus a stale summary count of "27 utility scripts" in the Overview table) and its sibling `migrate-directory-padding.sh` is likewise not named individually — so no existing per-script-name convention is being broken by omission. Refreshing the stale "27" count is the substantive content fix available; adding the new script's name to the representative sample list is optional polish, not required by any mechanical check.
- Adding the manifest entry will trigger a new, separate, **non-blocking** ADVISORY the next time `check-extension-docs.sh` runs (`core script never deployed: scripts/migrate-state-legacy-fields.sh`), because the script is declared in the source-store manifest but has never been copied to `.claude/scripts/`. This is expected and does not regress gate 3 (confirmed by reading `verify-deploy.sh`'s gate 3 logic — see Risks).
- Recommended edit target (confirmed): `agent-system/extensions/core/manifest.json` and `agent-system/extensions/core/README.md`, per `rules/source-store-deploy-boundary.md` — never the deployed `.claude/**` copies.

## Context & Scope

Scope is narrowly the one declared-vs-deployed parity defect named in the dispatch: `scripts/migrate-state-legacy-fields.sh` is live and executable in the core extension's source store but was never added to `provides.scripts` in `core/manifest.json`, so `check-extension-docs.sh`'s undeclared-script check (`check_undeclared_scripts`, documented as Rule Q in that script's header) fails for `[core]`. This is one of two causes of the `verify-deploy.sh --skip-slow` regression from FAIL 1/33 to FAIL 2/33 noted in `specs/reviews/review-2026-10-02.md`; the other cause (a gate 13 orphan false positive) is explicitly out of scope — it belongs to a concurrent sibling task (324, researching `lua/neotex/plugins/ai/shared/extensions/verify.lua` and `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`), confirmed to have no file overlap with this task's territory.

No external research was needed; this is entirely a codebase-internal consistency defect with a well-documented provenance (task 279 phase 5, commit `8fdfff0bf`).

## Findings

### Codebase Patterns

**Defect confirmed independently.**
```
$ git ls-files agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh
agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh   # tracked, present
$ python3 -c "...: 'migrate-state-legacy-fields.sh' in provides.scripts" -> False
$ bash .claude/scripts/check-extension-docs.sh | grep -A3 '\[core\]'
[core]
  FAIL: script file on disk NOT in provides.scripts: scripts/migrate-state-legacy-fields.sh
  WARN: README.md older than manifest.json (possible drift)
```

**Provenance verified.** `git show 8fdfff0bf --stat` confirms the script was added in "task 279 phase 5: ship consumer-runnable migrate-state-legacy-fields.sh" alongside plan/progress updates, with no manifest.json change in that commit. Task 279 is completed and archived (confirmed via ROADMAP.md / review text), matching the dispatch's "nothing else will return to this" claim.

**`provides.scripts` structure.** The array in `agent-system/extensions/core/manifest.json` is a flat, alphabetically-sorted-within-directory-groups JSON string array (199 entries currently, e.g. `..., "memory-harvest.sh", "memory-retrieve.sh", "migrate-directory-padding.sh", "orchestrate-batch-admit.sh", ...`). The alphabetically correct insertion point for `"migrate-state-legacy-fields.sh"` is immediately after `"migrate-directory-padding.sh"` and before `"orchestrate-batch-admit.sh"`.

**`check_undeclared_scripts` mechanics** (`.claude/scripts/check-extension-docs.sh`, function at line 549, Rule Q): iterates `git ls-files "$ext_path/scripts"` (so the file must be git-tracked — it is) and fails for any path not present in `.provides.scripts[]` via a `jq -e` membership test, skipping anything under a `deprecated/` subdirectory. Adding the one string is sufficient to clear this FAIL; no other mechanism gates on this array shape.

**README.md is a representative-sample inventory, not an exhaustive one.** `agent-system/extensions/core/README.md`'s Architecture tree (lines 62–153) lists scripts as:
```
├── scripts/                   # 27 utility scripts
│   ├── check-extension-docs.sh, export-to-markdown.sh
│   ├── install-extension.sh, uninstall-extension.sh
│   ├── memory-retrieve.sh, validate-*.sh
│   └── lint/
```
This "27" count is already stale by a wide margin — `provides.scripts` has 199 entries, not 27 — a pre-existing drift unrelated to this specific script. No individual migration script (including the sibling `migrate-directory-padding.sh`, which has existed in the manifest for longer) is named in this sample list. Refreshing the count (or wording it as approximate, matching the Overview table's own "15+", "11", etc. style used elsewhere in the same README) is the one content-level fix this task's "refresh if not" instruction clearly licenses; inserting the new script's literal filename into the representative sample is optional and not required by any check (`check_referenced_scripts_declared`, Rule E, only fails in the *reverse* direction — a script named in docs but missing from `provides.scripts` — which does not apply here).

**README `WARN` is a pure mtime comparison, not content-based.** `check_readme_vs_manifest()` (line 979) does exactly this:
```bash
readme_mtime=$(stat -c %Y "$readme" ...)
manifest_mtime=$(stat -c %Y "$manifest" ...)
[[ "$readme_mtime" -lt "$manifest_mtime" ]] && info "WARN: README.md older than manifest.json (possible drift)"
```
Current mtimes: `manifest.json` = 1790953071 (2026-10-02), `README.md` = 1788387806 (~2 weeks older). Any edit to README.md that is saved after the manifest.json edit clears this WARN regardless of what changes — but since the "27 scripts" count is independently stale and directly on-topic, making that edit (rather than a no-op touch) is the right move and satisfies both the dispatch's instruction and good hygiene in one edit.

**New advisory expected after the fix — not a regression.** `check_core_deploy_advisory` (Rule O, around line 446) separately checks, for every `provides.scripts` entry, whether a deployed copy exists at `.claude/scripts/<name>`:
```bash
[[ -f "$deployed" ]] || advisory "core script never deployed: scripts/$s (regenerate via <leader>al 'Reload All', or bash .claude/scripts/deploy-headless.sh)"
```
Verified: `.claude/scripts/migrate-state-legacy-fields.sh` does **not** exist (the script has never been deployed, only shipped to the source store). Once the manifest entry is added, this check will start emitting a new `ADVISORY: core script never deployed: scripts/migrate-state-legacy-fields.sh` line. This is an ADVISORY, not a FAIL (`check-extension-docs.sh` only exits non-zero on FAIL, confirmed by its own exit-code documentation and by `check_core_deploy_advisory`'s doc comment). It does not reintroduce gate 3's FAIL state. See Risks for the one way it *could* matter (`STRICT_CORE_DEPLOY=1`).

**`verify-deploy.sh` gate 3 will not be newly broken by the advisory.** Gate 3's logic (lines 340–390) runs `check-extension-docs.sh --quiet` for the primary pass/fail (ADVISORY lines are explicitly excluded from the FAIL-extraction logic there: "ADVISORY: lines are deliberately excluded"), then separately re-runs with `STRICT_CORE_DEPLOY=1` but only counts hits matching the literal substring `events-` (`grep -c 'events-'`) — a narrower, unrelated check for undeployed event files. `scripts/migrate-state-legacy-fields.sh` does not match that grep pattern, so the new advisory cannot cause gate 3's `STRICT_CORE_DEPLOY` sub-check to regress either.

**Source/deploy boundary confirmed.** `.claude-extensions.json`'s `extensions.core.source_dir` resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core`, confirming `agent-system/extensions/core/manifest.json` and `agent-system/extensions/core/README.md` are the correct (and only) edit targets, per `rules/source-store-deploy-boundary.md`. `.claude/manifest.json` / `.claude/README.md` equivalents are disposable deploy artifacts and must not be hand-edited.

**Territory / concurrency.** The sibling task 324 (same orchestrate cycle) declares `file_scope` of `lua/neotex/plugins/ai/shared/extensions/verify.lua` and `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md` — neither overlaps this task's edit targets (`core/manifest.json`, `core/README.md`). No coordination needed beyond the standard re-read-before-edit discipline.

### External Resources

None consulted — this is a pure internal consistency defect with no external API/library surface; no WebSearch/WebFetch was needed.

## Recommendations

1. In `agent-system/extensions/core/manifest.json`, add the string `"migrate-state-legacy-fields.sh"` to the `provides.scripts` array, placed immediately after `"migrate-directory-padding.sh"` (alphabetical order within that neighborhood is already the prevailing convention in this array).
2. In `agent-system/extensions/core/README.md`, refresh the stale script count in the Overview table (currently "27", actual count is 199 as of this research) and/or in the Architecture tree's `scripts/` comment line. This single edit both addresses genuine content drift and clears the mtime-based `README.md older than manifest.json` WARN as a side effect. Naming the specific new script in the representative sample list is optional (no sibling migration script is named there either); if the implementer chooses not to, note why in the summary so a future reader does not mistake the omission for an oversight.
3. Re-run `bash .claude/scripts/check-extension-docs.sh` and confirm `[core]` returns clean of its prior FAIL/WARN (expect one new, non-blocking `ADVISORY: core script never deployed: scripts/migrate-state-legacy-fields.sh` line — this is correct and expected, not a new defect to chase; do not attempt to deploy the script as part of this task unless the task description is revised to ask for that explicitly).
4. Re-run `bash .claude/scripts/verify-deploy.sh --skip-slow` (or just gate 3) and confirm it returns to FAIL 1/33 (i.e., only the gate-13 orphan issue from the sibling task remains, not this one).
5. No change needed to task 250 beyond the confirmation this report provides; task 250 already records this as explicitly out of its own scope pending this re-check.

## Decisions

- Edit target confirmed as `agent-system/extensions/core/manifest.json` + `agent-system/extensions/core/README.md` (source store), never `.claude/**` (deploy artifact) — consistent with `rules/source-store-deploy-boundary.md` and verified via `.claude-extensions.json`'s `source_dir` field.
- The README fix is scoped to refreshing the stale script count (and/or wording), not to writing an exhaustive per-script enumeration; this matches the README's existing representative-sample style and avoids scope creep into an unrelated, much larger stale-count cleanup.
- Deploying the script to `.claude/scripts/` is explicitly NOT part of this task's scope; the resulting ADVISORY (not FAIL) is an expected, acceptable, and separately-actionable state, not a defect this task must also close.

## Risks & Mitigations

- **Risk**: Implementer accidentally edits the deployed `.claude/` copies of manifest.json/README.md instead of the source store, which would appear to fix the problem locally but get silently overwritten on the next `deploy-headless.sh`/Reload All. **Mitigation**: edit only under `agent-system/extensions/core/`, confirmed above as the resolved `source_dir`.
- **Risk**: Misreading the new post-fix ADVISORY line as a leftover defect and attempting an out-of-scope deploy step. **Mitigation**: this report documents explicitly that the advisory is expected, non-blocking, and does not affect `verify-deploy.sh` gate 3's pass/fail outcome (traced through both the general `--quiet` FAIL-only extraction and the narrower `STRICT_CORE_DEPLOY`/`events-` grep).
- **Risk**: Inserting the new array entry at the wrong location breaks JSON validity or an unrelated ordering-sensitive check. **Mitigation**: `provides.scripts` is a plain JSON string array with no ordering-sensitive consumer found in this research (membership-only `jq -e` test in `check_undeclared_scripts`); alphabetical placement is a style convention, not a functional requirement, so a syntactically valid insertion anywhere in the array is safe, but following the existing local-alphabetical pattern (next to `migrate-directory-padding.sh`) keeps the diff minimal and readable.

## Context Extension Recommendations

None — this is a meta/system task entirely internal to already-well-documented `.claude/`/`agent-system/` conventions (`check-extension-docs.sh`'s own in-file documentation and `rules/source-store-deploy-boundary.md` already cover everything needed). No new context file is warranted.

## Appendix

- Search queries used: none (WebSearch not needed); codebase commands used:
  - `bash .claude/scripts/check-extension-docs.sh` (reproduced FAIL/WARN for `[core]`)
  - `git ls-files agent-system/extensions/core/scripts/migrate-state-legacy-fields.sh`
  - `python3 -c "..."` membership checks against `provides.scripts` in `manifest.json`
  - `git show 8fdfff0bf --stat` (provenance)
  - `grep -n` across `.claude/scripts/check-extension-docs.sh` and `.claude/scripts/verify-deploy.sh` for `check_undeclared_scripts`, `check_readme_vs_manifest`, `check_core_deploy_advisory`, and gate 3 logic
  - `python3 -c "..."` reading `.claude-extensions.json`'s `source_dir` for `core`
- References: `specs/reviews/review-2026-10-02.md` (filing review), `specs/ROADMAP.md` line naming task 323, `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/README.md`, `.claude/scripts/check-extension-docs.sh`, `.claude/scripts/verify-deploy.sh`.
