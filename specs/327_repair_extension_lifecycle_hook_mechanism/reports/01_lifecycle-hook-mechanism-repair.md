# Research Report: Task #327

**Task**: 327 - Repair the extension lifecycle hook mechanism: broken resolver schema, absent
return-code channel, uninvoked verification stage
**Started**: 2026-10-03
**Completed**: 2026-10-03
**Effort**: medium (one file carries all four defects; fix is surgical, test-writing is the bulk
of the work)
**Dependencies**: None (deliberately no dependency edge on the skeleton-plan follow-up work;
region-disjoint on the same file — see Findings)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/skill-base.sh`, extension
manifests, `.claude-extensions.json`, deployed `.claude/` tree, `check-extension-docs.sh`,
`measure-eager-context.sh`, `creating-extensions.md`, `test-skill-base-lifecycle.sh`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All three defects named in the dispatch are confirmed verbatim against the live source store,
  at the exact line numbers given (`skill-base.sh:147`, `:190-191`, `:607`/`:622-624`).
- **A fourth defect, not named in the dispatch, was discovered and is load-bearing for the
  acceptance criterion**: even after fixing the resolver (defect 1), the `nix` preflight hook
  still would not fire, because `skill_run_extension_hook`'s `hook_path` construction
  (`"${ext_dir}/${hook_script}"`) assumes the deployed extension directory mirrors the source
  layout (`scripts/` subdirectory under the extension), but the deploy pipeline actually
  flattens every `provides.scripts` entry straight into `.claude/scripts/` — `.claude/extensions/
  <name>/` contains only `manifest.json` on disk today, confirmed empirically for every one of
  the 7 currently-loaded extensions. Fixing defect 1 alone leaves `hook_path` pointing at a
  nonexistent file, which the existing `[ -x "$hook_path" ]` check silently no-ops on (per the
  documented silent-skip-on-non-executable behavior) — so the hook would still never fire. This
  is Finding 4 below and must be fixed in the same change for the stated acceptance criterion
  ("prove it with the `nix` preflight hook") to be satisfiable at all.
- Recommended fix shape for all four, in one paragraph: (1) resolve `task_type -> extension name`
  by iterating `.extensions | to_entries[] | select(.value.status=="active")` and checking each
  active extension's OWN `manifest.json` `.task_type` field (mirroring
  `measure-eager-context.sh:234`'s already-correct object-schema pattern, but adding the
  per-manifest `task_type` read the dispatch calls out); (2) resolve `hook_path` against the
  flat deployed location (`.claude/scripts/$(basename "$hook_script")`), not against
  `${ext_dir}/${hook_script}`, while still reading the manifest itself from
  `${ext_dir}/manifest.json` (that half of the path IS correct today); (3) make the hook's exit
  code observable to the caller via a new return channel, keeping every existing call site's
  disposition non-blocking (no documented contract flip — see Decisions); (4) give the
  `verification` stage a live call site inside `skill_validate_task_artifacts()` /
  `command-gate-out.sh` (the one gate-out path that already runs on every task), rather than
  leaving it in the never-called `skill_validate_artifact()`.
- No extension manifest anywhere declares a `verification` hook today, so wiring stage 3's call
  site is forward-looking (no existing hook script will fire from it yet) — this is expected and
  does not block the acceptance criterion, which is scoped to resolver + rc + verification
  call-site + resolver test coverage, not to every extension adopting `verification`.

## Context & Scope

Scope is exactly the three defects named in the dispatch, plus the deploy-layout mismatch
discovered during verification of defect 1's fix feasibility (Finding 4). The dispatch's
"Deliberately un-sequenced overlap" section instructs against adding a dependency edge on the
skeleton-plan follow-up work; this report does not revisit that call — it is settled and
out of scope here. As of this research pass, that sibling task (titled *"Surface skeleton-plan
follow-ups at completion under the batch engine"*) shows `status: "completed"` in
`specs/state.json`, which if accurate at implementation time removes even the theoretical overlap
risk the dispatch flagged; this is a non-blocking observational note, not an instruction to verify
or act on it.

All investigation was read-only against the source store (`agent-system/extensions/core/`) and
the live deployed tree (`.claude/`) and `.claude-extensions.json`. No files were modified.

## Findings

### Codebase Patterns

**Finding 1 — Resolver queries a dead key (confirmed, `skill-base.sh:136-153`).**
`skill_get_extension_dir()` at line 147 runs:
```
jq -r --arg tt "$task_type" '.loaded_extensions // [] | .[] | select(.task_type == $tt) | .name' "$extensions_json"
```
`.claude-extensions.json`'s live top-level keys are `["extensions","version"]`; `.loaded_extensions`
has never existed in the live file, so this query always evaluates against `// []`'s fallback and
returns empty for every `task_type`. `grep -rn "loaded_extensions"` across the entire repo (all
`.sh`/`.json` files) returns exactly this one line — it is the sole surviving consumer of the dead
key anywhere in the codebase. Every other consumer (`measure-eager-context.sh:234`,
`check-consumer-freshness.sh`, `check-extension-docs.sh`) already uses
`.extensions | to_entries[] | select(.value.status=="active") | .key` against the object schema.
Per-extension entries under `.extensions.<name>` carry no `task_type` field (verified: keys are
`data_skeleton_files`, `merged_sections`, `loaded_at`, `source_git_head`, `installed_files`,
`source_dir`, `installed_dirs`, `status`, `version`) — `task_type` lives only in each extension's
OWN `manifest.json` (e.g. `agent-system/extensions/nix/manifest.json`'s top-level `"task_type":
"nix"`, `.../lean/manifest.json`'s `"task_type": "lean4"`, `.../nvim/manifest.json`'s
`"task_type": "neovim"`). A correct resolver must therefore do a two-step join: list active
extension names from `.claude-extensions.json`, then for each, read its deployed
`.claude/extensions/<name>/manifest.json` (confirmed present and correct at that path for every
extension) and compare `.task_type`.

**Finding 2 — No return-code channel (confirmed, `skill-base.sh:159-192`, decisively
190-191).** The invocation:
```bash
"$hook_path" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation" || \
  echo "[skill-base] WARNING: Extension hook '${hook_name}' exited non-zero (non-blocking)"
```
is `skill_run_extension_hook`'s last statement. Bash's function return code defaults to the last
command's exit status — but that last command is the `echo` in the `||` branch (exit 0) or the
hook invocation itself (whatever it returned) in the success branch; either way nothing captures
or re-exposes the hook's actual rc to the four call sites (`skill_preflight_update`,
`skill_context_injection`, `skill_validate_artifact`, `skill_postflight_update`), none of which
inspect the function's return value today. `docs/guides/creating-extensions.md:700-702` documents
this as NORMATIVE: "Exit non-zero: warning logged (non-blocking, skill continues)." Any fix must
preserve that default behavior for every existing call site — see Decisions below for the
specific disposition recommendation.

**Finding 3 — `verification` stage has no live call site (confirmed).** Its only invocation is
inside `skill_validate_artifact()` (line 624), which itself has zero callers outside
`skill-base.sh` and `test-skill-base-lifecycle.sh` — confirmed via
`grep -rln "skill_validate_artifact\b"`. `command-gate-out.sh` (the actual gate-out path every
task's postflight runs through) calls the DIFFERENT function `skill_validate_task_artifacts()`
(`skill-base.sh:688`), a directory-wide sweep over `reports:report`, `plans:plan`,
`summaries:summary` pairs that calls `validate-artifact.sh` directly per file and never touches
`skill_run_extension_hook` at all — confirmed by reading its full body (lines 688-780+) and by
`command-gate-out.sh`'s own comments at lines 272/275 explicitly distinguishing the two. Several
skills (`skill-reviser/SKILL.md:309`, and cslib/present extension skills) call
`validate-artifact.sh` inline, bypassing both functions. The `test-skill-base-lifecycle.sh` suite
explicitly lists `skill_get_extension_dir`, `skill_run_extension_hook`, and
`skill_validate_artifact` as "Residual (uncovered by this suite, out of scope per this suite's own
authoring plan)" in its final summary block (line ~824) — confirming no test exercises this path
today, which is also why the breakage in Findings 1/2/4 went unnoticed.

**Finding 4 (new, not named in the dispatch) — hook script paths are written for a deploy layout
that does not exist.** `nix/manifest.json`'s `hooks` object declares
`"preflight": "scripts/nix-preflight.sh"` and `"context_injection": "scripts/nix-context.sh"` —
paths with a `scripts/` prefix, matching the SOURCE STORE layout
(`agent-system/extensions/nix/scripts/nix-preflight.sh`, which does exist). But
`skill_get_extension_dir()` returns the DEPLOYED extension directory
(`.claude/extensions/nix`), and empirically that directory contains ONLY `manifest.json` —
confirmed via `ls -la .claude/extensions/nix/` and `.claude/extensions/nvim/` (same pattern) —
there is no `.claude/extensions/nix/scripts/` subdirectory on disk, for any of the 7 loaded
extensions (`jq '.extensions | to_entries[] | .value.installed_dirs'` returns `[]` for every one).
The actual deployed files live flattened at `.claude/scripts/nix-preflight.sh` and
`.claude/scripts/nix-context.sh` (confirmed present, executable). This is not a one-off
accident: `nix/manifest.json`'s OWN `provides.scripts` array for the same two files uses bare
filenames (`["nix-preflight.sh", "nix-context.sh"]`, no `scripts/` prefix) — the very same
manifest encodes the correct flat-deploy convention in `provides.scripts` and the wrong
nested-deploy assumption in `hooks`, in two adjacent blocks. `check-extension-docs.sh:445`
independently corroborates the flat-deploy target for `provides.scripts`:
`deployed="$REPO_ROOT/.claude/scripts/$s"`. No existing validator checks the top-level `hooks`
object's paths against deployed reality at all — `check-extension-docs.sh` and
`script-inventory.sh` only ever inspect `provides.hooks` (the unrelated Claude-Code-native
settings-hook array), never the lifecycle `hooks` object this task is about. **Consequence**:
fixing Finding 1's resolver alone is necessary but not sufficient — `hook_path` must ALSO be
resolved against the flat deployed location
(e.g. `.claude/scripts/$(basename "$hook_script")`), not against `"${ext_dir}/${hook_script}"`,
for the `nix` preflight hook (or any declared hook) to actually be found and executed. The
`${ext_dir}/manifest.json` half of the current resolution is correct and should be kept as-is —
only the hook-SCRIPT half of the path needs to change.

**Contract facts reconfirmed (no drift from dispatch):** four stages
(`preflight`, `context_injection`, `verification`, `postflight`); five positional args, no env
vars; hook stdout goes straight to console; missing hook keys or absent
`.claude-extensions.json` are silently skipped (`skill_get_extension_dir` returns 0/empty on a
missing file); `[ -x "$hook_path" ]` silently `return 0`s on a non-executable/absent script
(line 185) — this is exactly the mechanism that currently masks Finding 4's broken path, and will
keep masking any future hook_path mistake unless a loud warning is added there. `provides.hooks`
(Claude-Code-native settings-hook file-copy array) remains fully distinct from the top-level
`hooks` object (this mechanism) — `lean/manifest.json` has `provides.hooks: ["lean-lsp-register-
project.sh"]` and no top-level `hooks` key at all, i.e. zero lifecycle hooks declared, confirmed.

**Call-site caller correctness (not a defect):** `TASK_TYPE` is exported by
`skill_validate_input()` before any of the four `skill_run_extension_hook` call sites run
(confirmed via `creating-skills.md:91,381`), so the `$2` argument each call site passes is
already correct — the defect is confined to the resolver/path-construction inside
`skill_run_extension_hook`/`skill_get_extension_dir`, not to how callers invoke it.

## Decisions

- **Return-code channel disposition (dispatch's "DECIDE AND RECORD"): rc becomes observable to
  the caller; default disposition at every existing call site stays non-blocking.** No opt-in
  per-stage blocking mode is introduced. Rationale: none of the four current call sites
  (`skill_preflight_update`, `skill_context_injection`, `skill_validate_artifact`/future
  verification site, `skill_postflight_update`) inspects a return value today, and
  `docs/guides/creating-extensions.md:700-702`'s documented contract ("Exit non-zero: warning
  logged (non-blocking, skill continues)") is not contradicted by simply making the rc
  *available* — only by making it *block* something it doesn't block today. The implementer
  should: capture the hook's exit code into a local variable, `return` it (or echo it to a
  dedicated channel/global, consistent with this file's existing `SUBAGENT_STATUS`/
  `SKILL_VALIDATE_ERRORS`-style uppercase-global convention) from `skill_run_extension_hook`, and
  surface a non-zero rc through the unified event store (`_events_append_observable`, category
  `deviation`) alongside the existing console WARNING — mirroring how `skill_validate_artifact`
  already discriminates `_category` by status for its own verification event. This requires a
  small ADDITION to `creating-extensions.md`'s Hook Execution Contract section (documenting the
  new observability channel) but does not require changing the existing "non-blocking" sentence,
  since no existing behavior flips.
- **`verification` stage gets a live call site rather than being retired.** Recommended site:
  inside `skill_validate_task_artifacts()` (or immediately around its call in
  `command-gate-out.sh`), which is the one path that already runs on every task's gate-out,
  rather than resurrecting `skill_validate_artifact()` (which has no callers and would need one
  added anyway). This keeps the `verification` stage name's meaning intact ("after artifact
  validation") while attaching it to code that actually executes. Rationale for not retiring: no
  cost evidence was found for keeping it (the call is one line, non-blocking, silently skipped
  when no extension declares it — which is every extension today), and retiring it would require
  editing the contract block (lines 114-131) and the `creating-extensions.md` stage-mapping table
  in the same change for no behavioral gain, whereas wiring it costs about the same effort and
  leaves the mechanism complete for a future extension author.
- **Hook script path resolution: resolve against the flat deployed `.claude/scripts/` directory,
  not against `${ext_dir}/${hook_script}`.** This is the fix for Finding 4. The
  `${ext_dir}/manifest.json` lookup (for discovering which hook script name was declared) is
  unaffected and stays as-is.

## Recommendations

1. In `skill_get_extension_dir()` (`skill-base.sh:136-153`): replace the `.loaded_extensions`
   query with a loop over `.extensions | to_entries[] | select(.value.status=="active") | .key`
   (mirroring `measure-eager-context.sh:234`), and for each active name check
   `.claude/extensions/<name>/manifest.json`'s `.task_type == $task_type`; return the matching
   `.claude/extensions/<name>` on first match, empty otherwise. Keep the existing early return on
   missing `.claude-extensions.json`.
2. In `skill_run_extension_hook()` (`skill-base.sh:159-192`): change the `hook_path` line from
   `hook_path="${ext_dir}/${hook_script}"` to resolve the script against
   `.claude/scripts/$(basename "$hook_script")` (Finding 4's fix) while still reading
   `manifest="${ext_dir}/manifest.json"` as today. Capture the hook invocation's exit code,
   return/expose it per the Decisions entry above, and consider upgrading the current silent
   `[ -x "$hook_path" ]` no-op (line 185) to a loud one-line stderr NOTE when the manifest
   declares a hook but the resolved script is missing or non-executable — this is the exact
   failure mode Finding 4 hid for however long these two manifests have declared dead hooks, and
   a future hook-path typo should not get the same silent treatment.
3. Wire the `verification` stage into `skill_validate_task_artifacts()` /
   `command-gate-out.sh`'s call site (see Decisions). Leave `skill_validate_artifact()` as-is
   (still unused, still safe) or fold its hook call out of it — the plan should decide which,
   but either way the new live call site is the deliverable, not a change to the dead function's
   signature.
4. Extend `test-skill-base-lifecycle.sh` (or add a new focused test file) to cover: (a) the
   resolver against a fixture `.claude-extensions.json` built in the REAL object schema (this
   file already has a working example of that fixture shape in
   `build_deploy_gate_source_repo()`, lines ~174-191 — reuse that technique, not the fixture
   content, since that one is purpose-built for the deploy-freshness gate); (b) an end-to-end
   case proving a declared hook with a script that lives under a fixture's `.claude/scripts/`
   actually executes (the "prove it with the `nix` preflight hook" acceptance line — a synthetic
   fixture hook script is more test-stable than invoking the real `nix-preflight.sh`, which
   probes real `nix` tooling availability); (c) a case where the fixture hook script exits
   non-zero and the new rc channel observably reflects that to the caller; (d) remove
   `skill_get_extension_dir`/`skill_run_extension_hook` from the suite's "Residual...out of
   scope" list once covered.
5. Update `creating-extensions.md`'s Hook Execution Contract section with the new rc-observability
   addition (Decisions, bullet 1) — an addition, not a rewrite of the non-blocking-default
   sentence.
6. Optional hardening (not required for acceptance, flagged for the plan's judgment): add a check
   to `check-extension-docs.sh` validating that every top-level `hooks` object value resolves to
   an actual file under `.claude/scripts/` once deployed — closing the blind spot Finding 4
   exploited (today's checks only ever look at `provides.hooks`, never this `hooks` object).

## Risks & Mitigations

- **Risk**: changing `hook_path` resolution could regress some extension that (unlike `nix`/
  `nvim`) actually has a nested `installed_dirs` layout. **Mitigation**: confirmed empirically
  that `installed_dirs` is `[]` for all 7 currently-loaded extensions — no such nested layout
  exists today to regress. If a future extension ever gets one, the flat-`.claude/scripts/`
  resolution would need revisiting then, not now.
- **Risk**: making the hook rc observable could be mistaken for a license to start blocking on
  it. **Mitigation**: the Decisions section above is explicit that no call site's disposition
  changes; this should be stated just as explicitly in the plan and in code comments at the
  change site.
- **Risk**: the three-strikes/territory note about `skill-base.sh` being broad and widely edited
  (dispatch's "Deliberately un-sequenced overlap" section) could cause `orchestrate-batch-admit.sh`
  to defer this task if co-scheduled with the skeleton-plan follow-up work. **Mitigation**:
  already addressed by the dispatch itself (dispatch alone, or alongside tasks whose
  `file_scope` excludes `skill-base.sh`); this report adds no new guidance here, only the
  observation that the sibling task's `state.json` status currently reads `completed`, which — if
  still true at implementation time — removes the concurrency risk entirely.

## Context Extension Recommendations

- **Topic**: top-level lifecycle `hooks` object path validation.
- **Gap**: `check-extension-docs.sh` and `script-inventory.sh` validate `provides.scripts` and
  `provides.hooks` deployment but never validate the lifecycle `hooks` object's script paths
  against deployed reality — the exact blind spot that let Finding 4 ship undetected in two
  extensions' manifests.
- **Recommendation**: add a Rule to `check-extension-docs.sh` (see Recommendation 6 above) that
  resolves every `hooks.<stage>` value via `basename` against `.claude/scripts/` and advisories
  when the file is absent or non-executable, mirroring the existing `provides.scripts`
  deployment check at line 445.

## Appendix

- Search queries / commands used: `grep -rn "loaded_extensions"` (repo-wide, one hit);
  `grep -rln "skill_run_extension_hook"` / `skill_validate_artifact\b"` (caller enumeration);
  `jq` introspection of `.claude-extensions.json` (`keys`, `.extensions | keys`, per-extension
  object shape, `installed_dirs`); `jq '{task_type, task_types, hooks}'` across all 7 extension
  manifests; `ls -la .claude/extensions/<name>/` for `nix` and `nvim` (confirmed manifest-only,
  no `scripts/` subdir); `diff` of `.claude/scripts/skill-base.sh` vs. the source-store copy in
  the resolver/hook region (confirmed byte-identical, i.e. the deployed copy IS what runs at
  dispatch time); reading `agent-system/extensions/core/docs/guides/creating-extensions.md:680-
  713` (Hook Execution Contract, Lifecycle Stage Mapping table); reading
  `test-skill-base-lifecycle.sh`'s `build_deploy_gate_source_repo()` fixture technique and its
  final "Residual" summary block.
- References: `agent-system/extensions/core/scripts/skill-base.sh` (lines 136-192, 607-630,
  688-780); `agent-system/extensions/nix/manifest.json`; `agent-system/extensions/nvim/
  manifest.json`; `agent-system/extensions/lean/manifest.json`; `agent-system/extensions/core/
  scripts/measure-eager-context.sh:220-245`; `agent-system/extensions/core/scripts/
  check-extension-docs.sh:440-455`; `agent-system/extensions/core/scripts/command-gate-out.sh`;
  `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`; `agent-system/
  extensions/core/docs/guides/creating-extensions.md:680-713`.
