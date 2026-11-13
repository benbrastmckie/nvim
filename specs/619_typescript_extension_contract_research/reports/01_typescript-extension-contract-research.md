# Research Report: Task #619

**Task**: 619 - Survey the real extension file contract and establish the 2026 TypeScript toolchain detection matrix
**Started**: 2026-11-13
**Completed**: 2026-11-13
**Effort**: medium
**Dependencies**: None (foundational task for the typescript-extension topic chain: 619 -> 620 -> 621 -> 622 -> 623)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/{python,rust,web,nix,lean}/`, `agent-system/extensions/core/{context/guides,docs/guides,docs/reference/standards,scripts/lib,scripts/check-extension-docs.sh}`, `lua/neotex/plugins/ai/shared/extensions/{manifest,merge}.lua`
- WebSearch: TypeScript 7.0 GA, ESLint v10, Bun text lockfile, Vite 8/Rolldown, Oxlint/Biome 2, Deno 2 package.json compat
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The loader mechanically requires only `manifest.json` with non-empty `name`/`version`/`description`
  to load at all. `EXTENSION.md`, `README.md`, and `index-entries.json` are **convention-only**,
  enforced by a separate lint script (`check-extension-docs.sh`), never by the loader
  (`manifest.lua`/`loader.lua`/`merge.lua`). `provides` and `merge_targets` are validated *in shape*
  if present but are themselves optional at the loader-validation layer, even though the dev guide
  lists `merge_targets` as "Yes" (a documentation convention, not an enforced load-time gate).
- Every manifest/index field has a concrete, independently-traceable consumer (Outcome 2's table
  below) -- none are vestigial, but several (`keywords`, `merge_targets.opencode_json`) are
  discoverability/secondary-consumer fields rather than primary dispatch-path fields.
- The lifecycle-hook contract (`hooks.{preflight,context_injection,verification,postflight}`) has a
  **hard prerequisite** that is easy to miss when scaffolding a new extension: a hook never fires at
  all unless the declaring manifest's top-level `task_type` string-equals the dispatched task's
  `task_type`. A resource-only extension (no `task_type`) forfeits every hook regardless of how
  `hooks` is populated.
- `keyword_overrides` and `hard_contracts` are two independently-resolved, differently-shaped
  blocks: `keyword_overrides` is consumed at `/task` creation time by `task-type-detect.sh` (step 4b,
  whole-word first-match-wins, scan-order is alphabetical-by-directory and matters);
  `hard_contracts` is a one-level `{task_type: [...]}` map resolved once per `--hard` dispatch by
  `routing_lookup_flat()` in `manifest-routing-lib.sh`, consumed by `orchestrate-build-dispatch.sh`'s
  Stage 3.5 to build the `<hard-mode-contracts>` prompt block -- it has no relationship to agent
  routing at all.
- The 2026 TypeScript toolchain has shifted meaningfully since early-2026 training data: TypeScript
  7.0 (Go-native `tsgo` compiler) reached GA in July 2026, meaning `tsc` **itself** is now the fast
  native binary for any project on `typescript@7.x`; ESLint v10 (Feb 2026) removed legacy
  `.eslintrc*` support entirely; Bun's text `bun.lock` is now the default lockfile (not the legacy
  binary `bun.lockb`); and Vite 8 (stable March 2026) made Rolldown the default production bundler,
  replacing esbuild+Rollup under the hood. The detection matrix below is written against this
  current state, not assumed from pretraining.
- Recommended approach for the downstream design task (620): treat `python`/`rust` as the file-count
  floor (no rules, scripts, hooks, or settings-fragment needed) and `web`/`nix` as the floor-plus-hooks
  precedent for a TypeScript extension that will need a `preflight`/`context_injection` hook pair to
  report which toolchain combination it detected, mirroring `nix`'s two-hook shape exactly.

## Context & Scope

This is task 1 of a 5-task chain (619-623) adding a standalone `typescript` extension to the source
store, with the existing `web` extension made to depend on it. This task's job is purely
investigative: establish the ground-truth file contract (not the aspirational one in the dev guide
alone) by diffing five existing extensions of increasing complexity, and produce the detection
matrix the design task (620) and implementation task (621) will consume directly. No files under
`agent-system/extensions/` were created or modified by this task -- it is research-only.

Per `.claude/rules/source-store-deploy-boundary.md`'s Task Siting subsection, this task (and its
four successors) is correctly sited in this repository because every downstream edit target
(`agent-system/extensions/typescript/`, `agent-system/extensions/web/manifest.json`) resolves to a
`source_dir` that exists on disk here.

## Findings

### Codebase Patterns

**Extension complexity spectrum (file inventory diff)**:

| Extension | agents/ | skills/ | rules/ | scripts/ | hooks (top-level) | settings-fragment.json | commands/ | hard_contracts |
|---|---|---|---|---|---|---|---|---|
| `python` | 2 | 2 | 0 | 0 | none | no | 0 | no |
| `rust` | 2 | 2 | 0 | 0 | none | no | 0 | no (but has `keyword_overrides`) |
| `web` | 2 | 2 | 1 | 0 | none | yes | 0 | no |
| `nix` | 2 | 2 | 1 | 2 | `preflight`, `context_injection` | yes | 0 | no |
| `lean` | 2 | 4 | 2 | ~40 (incl. test fixtures) | `lean-lsp-register-project.sh` (as `provides.hooks`, distinct from top-level `hooks`) | yes | 2 | yes (`lean4`) |

`python` and `rust` are the floor: a working, loadable, routable extension needs nothing beyond
`manifest.json` + `EXTENSION.md` + `README.md` + two agents + two skills + `index-entries.json` +
`opencode-agents.json`. Neither declares `rules`, `scripts`, `hooks`, or `settings-fragment.json` --
confirming these are all optional add-ons, not baseline requirements.

**Required-vs-convention file inventory (Outcome 1), ground-truthed against the loader code,
not just the dev guide prose**:

| File | Loader-enforced? | Mechanism |
|---|---|---|
| `manifest.json` | **Yes, hard** | `manifest.lua`'s `REQUIRED_FIELDS = {"name","version","description"}`; a missing or empty-string field fails `M.validate()` and the extension cannot load. |
| `manifest.json`'s `provides` | No (optional) | `validate_provides()` returns `true, nil` immediately if `manifest.provides` is absent; if present, every key must be one of the 12 `VALID_PROVIDES` categories and every value must be an array/table, or validation fails. |
| `manifest.json`'s `merge_targets` | No (optional at the loader-validation layer) | `validate_merge_targets()` returns `true, nil` if absent; if present, every entry needs both `source` and `target`. The dev guide marks this field "Yes" -- that is a documentation convention for a *useful* extension, not a load-time gate. |
| `EXTENSION.md` | **No -- convention-only** | Never read by `manifest.lua`/`loader.lua`'s validation path. Enforced only by `check-extension-docs.sh`'s lint (`check_file`, cited as "missing EXTENSION.md"), and only consumed functionally by `generate_claudemd()` if-and-only-if a manifest's `merge_targets.claudemd.source` actually names it. |
| `README.md` | **No -- convention-only** | Same: lint-enforced (`check-extension-docs.sh`), never loader-enforced. Not referenced by any `merge_targets` key by default. |
| `index-entries.json` | No -- explicitly "Recommended," not required | Absent file is a silent no-op for `M.copy_category`'s context-merge step; schema conformance (if present) is lint-checked by Rule T, never structurally required to load. |
| `opencode-agents.json` | No | Only consumed if `merge_targets.opencode_json` is declared; every sampled extension (python/rust/web/nix/lean) does declare it, making it a near-universal convention despite being structurally optional. |
| `scripts/*.sh` referenced by `provides.scripts` | **Yes, for that specific entry** | `provides.scripts` is a hand-maintained explicit list (unlike `index-entries.json`'s wholesale-directory convention) -- a script not listed there never deploys, with no lint catching the gap except `check-extension-docs.sh` Rule Q, and only on a lint run, not at load time. |

**Resource-only extensions** (no `task_type`, e.g. `slidev`) omit `EXTENSION.md`/`claudemd` entirely
and forfeit every lifecycle hook outright -- confirmed by `extension-development.md`'s own worked
example and `creating-extensions.md`'s "Prerequisite: A Declared task_type" section.

### Manifest and index-entries.json Schema Fields, Paired with Actual Consumers (Outcome 2)

**`manifest.json` top-level and `provides`/`merge_targets` fields**:

| Field | Consumer (script/function) | Notes |
|---|---|---|
| `name`, `version`, `description` | `manifest.lua`'s `validate_required_fields()` | Hard requirement; `name` is ALSO the sole core-identification key (`routing_core_manifest()`: `.name == "core"`), replacing the old, non-unique `routing_exempt: true` identification. |
| `task_type` | `skill_get_extension_dir()` in `skill-base.sh` (string-equality gate for all 4 lifecycle hooks); `manifest-routing-lib.sh`'s `routing_lookup()`/`routing_lookup_flat()` (both ladders key on it) | Omitting it forfeits routing AND every lifecycle hook. |
| `dependencies` | `loader.lua`'s recursive `manager.load()` resolution | Auto-loads silently; depth limit 5; cycle detection via loading-stack re-entry. |
| `provides.{agents,skills,commands,rules,context,scripts,hooks,docs,templates,systemd,root_files,data}` | `loader.lua`'s `M.copy_category` (per-category copy semantics) | `scripts`/`hooks`/`commands`/`skills`/`agents` deploy FLAT into `.claude/{category}/`; `context`/`docs` support directory-or-file entries (`entry_kind = "file_or_dir"`); only `manifest.json` itself is copied into a per-extension `.claude/extensions/{name}/` directory. |
| `routing_agents.{research,plan,implement}` | `manifest-routing-lib.sh`'s `routing_lookup()`, called from `command-route-agent.sh` | Five-step ladder: non-core exact -> non-core compound-base -> core exact -> core compound-base -> miss. Agent names are declared data, never derived by string surgery. |
| `hard_contracts.{task_type}` | `routing_lookup_flat()`, consumed by `orchestrate-build-dispatch.sh` Stage 3.5 | One-level map, NOT nested under an `op` key; resolves the same 4-step non-core/core ladder (no Step 5 "miss" distinction beyond empty output). Each entry is a plain additive basename or a `replace:{core-basename}:{override-path}` directive. |
| `keyword_overrides.{task_type}.{keywords,aliases}` | `task-type-detect.sh`'s `_dtd_scan_keyword_overrides()` (step 4b) and `_dtd_alias_remap()` (step 4e) | `keywords` matched whole-word, case-insensitive, first-match-wins scanning `.claude/extensions/*/manifest.json` in alphabetical directory order -- scan order is load-bearing. An extension with `routing_exempt: true` and no `routing_agents` block MUST NOT declare this (resolves to an undispatchable task_type). |
| `hooks.{preflight,context_injection,verification,postflight}` (top-level) | `skill-base.sh`'s `skill_run_extension_hook()`, called from `skill_preflight_update()`, `skill_context_injection()`, `command-gate-out.sh`, `skill_postflight_update()` respectively | Gated on exact `task_type` string match (see Outcome 3). Resolved by BASENAME against flat deployed `.claude/scripts/`, so the hook's script must ALSO appear in `provides.scripts` or it silently never deploys. |
| `observers.{name}.{script,topic,task_type,timeout_seconds}` | `routing_resolve_observers()`, invoked once from `orchestrate-cycle-postflight.sh`'s completion path | Resolve-ALL (not first-match-wins); prefix-aware on both `topic` and `task_type`; fires AFTER issue-log/metrics writes for that dispatch. A different seam from lifecycle hooks entirely -- do not conflate the two. |
| `merge_targets.{claudemd,settings,index,mcp,opencode_json}` | `loader.lua`'s `process_merge_targets()`/`reverse_merge_targets()`, reusing `merge.lua`'s `merge_settings`/`unmerge_settings`/`append_index_entries` | `validate_merge_targets()` in `manifest.lua` is **open-set**: an unrecognized key (e.g. a typo'd `"mcpp"`) validates structurally but is silently never dispatched by the deploy engine -- there is no validation-time rejection of an unrecognized-but-well-shaped key. |

**`index-entries.json` entry fields**, cross-checked against `check-extension-docs.sh`'s Rule T
schema-conformance check (the mechanical ground truth for the schema, since no JSON-Schema
validator is used -- it is a hand-written jq conformance check):

| Field | Required? | Consumer |
|---|---|---|
| `path` | Yes (Rule T fails if absent) | `merge.lua`'s `append_index_entries()` -- the dedupe/upsert key (replace-in-place if already present, by exact path match). |
| `domain` | Yes; enum `{core, project, system}` | Rule T schema check; read by `context-discovery.md`'s adaptive jq queries at agent runtime (grouping dimension, not a load gate by itself). |
| `subdomain` | Yes | Same as `domain` -- discovery grouping, not independently gated. |
| `summary` | Yes | Human/agent-readable one-line description surfaced in discovery queries. |
| `line_count` | Yes | Checked for accuracy against `wc -l` by Rule R (`check_line_count_accuracy`); kept in sync by `generate-context-line-counts.sh --write`. |
| `load_when.{agents,commands,task_types,always}` | Optional, but these 4 keys are the ONLY allowed `load_when` keys (Rule T fails on any other key, including an empty `languages`/`skills` array) | **Consumed by the dispatched agent itself**, via ad hoc `jq` queries it runs against the deployed `.claude/context/index.json` -- per `context-discovery.md`'s adaptive-query pattern. This is NOT an automatic pre-load: agent-body `@`-references are never auto-expanded at subagent spawn time (confirmed in `agent-frontmatter-standard.md`'s "`@`-References Are Not Auto-Expanded" section), so `load_when` is only as effective as the agent's own Stage 2 discovery query. |
| `keywords` | Optional | Free-text; no identified mechanical consumer beyond human/agent-driven grep/search -- a discoverability aid, not a load gate. |
| `description`, `tags` | **Forbidden** (Rule T explicitly fails on either) | `description` is considered a duplicate of `summary`; `tags` is a naming mismatch for `keywords`. The `python`/`web` samples read above correctly avoid both. |

### Lifecycle Hook Execution Contract (Outcome 3)

Confirmed directly against `creating-extensions.md`'s `#lifecycle-hooks` section:

- **Prerequisite (easy to miss)**: a hook fires at all only if the declaring extension's manifest
  carries a top-level `task_type` whose value **string-equals** the task_type of the task currently
  dispatched. The gate is exactly `[ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ]`
  inside `skill_get_extension_dir()` in `skill-base.sh`. `nix`'s two hooks (`preflight`,
  `context_injection`) work because `nix`'s manifest declares `task_type: "nix"` -- a per-domain
  precedent, not a cross-cutting one. There is NO extension-declarable seam for task-type-independent
  pre-dispatch injection; that shape (the `<memory-context>` block) is a hardcoded core call, not an
  extension hook.
- **Two distinct `hooks` concepts, easily confused**: top-level `"hooks": {}` (lifecycle scripts
  called in-place by `skill-base.sh`, never copied) vs. `"provides": {"hooks": []}` (file-copy
  targets deployed to `.claude/hooks/`, e.g. `lean`'s `lean-lsp-register-project.sh`). The `lean`
  sample in this survey uses the SECOND form, not the first -- `lean`'s manifest declares NO
  top-level `hooks` object at all, despite having a `hooks/` directory on disk.
- **4 stages, each with a fixed call site**: `preflight` from `skill_preflight_update()` (after
  status -> in_progress); `context_injection` from `skill_context_injection()` (before agent
  delegation); `verification` from `command-gate-out.sh` immediately after `skill_validate_task_artifacts`
  (on every gate-out); `postflight` from `skill_postflight_update()` (after status -> completed).
- **5 positional args to every hook script**: `$1 task_number`, `$2 task_type`, `$3 task_dir`,
  `$4 session_id`, `$5 operation` (`"research"` or `"implement"`). No environment variables are
  passed.
- **Exit codes are unconditionally non-blocking, no opt-in blocking mode exists**: exit 0 is
  success; any non-zero exit is logged as a warning and the skill continues regardless.
  `skill_run_extension_hook`'s literal last statement is always `return 0`. Observability is exposed
  via four globals (`SKILL_HOOK_LAST_RC`, `SKILL_HOOK_LAST_STATUS`, `SKILL_HOOK_LAST_NAME`,
  `SKILL_HOOK_LAST_PATH`), reset unconditionally at function entry, but no existing call site reads
  them, and a non-zero exit appends one `deviation`-category event to `specs/events.jsonl`.
- **Path resolution is BY BASENAME against the flat deployed `.claude/scripts/`**, never a nested
  per-extension path. A hook's manifest value (`"scripts/your-domain-preflight.sh"` or a bare
  filename) must therefore ALSO have a matching `provides.scripts` entry, or it resolves to a path
  the deploy never writes -- "this was the trap that left two shipped extensions' hooks dead."

### `keyword_overrides` and `hard_contracts` Resolution Mechanics (Outcome 4)

These are two unrelated schemas that happen to share superficial "map under a manifest key" shape.
Confirmed directly against `manifest-routing-lib.sh` and `task-type-detect.sh`:

**`keyword_overrides`** (consumed at `/task` creation time, NOT at dispatch time):
- Schema: `{ "<task_type>": { "keywords": [...], "aliases": [...] } }`.
- `keywords` matched at `/task` step 4b via `_dtd_scan_keyword_overrides()`: whole-word,
  case-insensitive (`\b<keyword>\b`) regex test against the task description, scanning
  `<extensions_dir>/*/manifest.json` in **alphabetical directory-name order**, first match wins and
  SHORT-CIRCUITS the entire rest of the detection sequence (step 4d's weak-signal table never runs).
  A single common word is a blunt, false-positive-prone lever -- precedence favors multi-word phrases.
- `aliases` matched at step 4e, strictly AFTER a task_type has already resolved via step 4c (project
  default) or 4d (weak-signal table): if the already-resolved string appears in an extension's
  `aliases` array, it is remapped. This step has no visibility into which keyword produced the
  already-resolved string.
- The key under `keyword_overrides` IS the resolved `task_type` directly -- never remapped or
  validated against the extension's own routing table. **Confirmed prior-art closure**: this is
  exactly the hazard task 210 (`fix_task_create_topic_assignment_order`) fixed by replacing the old
  first-match-wins 4d table with the current strong-anchor + `keyword_overrides` + weak-signal-threshold
  (`DTD_WEAK_THRESHOLD = 2`, distinct-keyword-count scoring) sequence recorded in
  `task-type-detect.sh`'s own header comment -- still the live mechanism today, not superseded since.
- Worked precedent for a new TypeScript extension: `rust`'s manifest declares
  `keyword_overrides.rust.keywords = ["rust","cargo","rustc","clippy","crates.io"]` with empty
  `aliases` -- directly analogous to what a `typescript` extension would need (see Recommendations).

**`hard_contracts`** (consumed once per `--hard` dispatch, at dispatch-build time):
- Schema: `{ "<task_type>": [ path_or_directive, ... ] }` -- deliberately ONE level, no `op` key,
  because a `--hard` dispatch's per-phase core-contract list already varies by `phase` inside
  `orchestrate-build-dispatch.sh`, not inside the manifest.
- Resolved through the SIBLING function `routing_lookup_flat(block, task_type)` -- never
  `routing_lookup()` -- sharing the identical 4-step non-core-exact -> non-core-compound ->
  core-exact -> core-compound precedence (no Step-5 "miss" distinction beyond empty output; uses
  `jq -c` since the resolved value is a JSON array, not a scalar).
- Each array entry is either a plain additive basename (appended after the phase's fixed core list)
  or a `replace:{core-basename}:{override-path}` directive (substitutes in place, preserving
  position). Both resolve through one renderer line in `orchestrate-build-dispatch.sh` Stage 3.5
  (`hard_contracts_block+="- context/contracts/${c}"`) with **no extension-namespacing** -- every
  entry must be a flat basename resolving directly under the single deployed `context/contracts/`
  directory, which is why a domain-prefixed basename (`lean4-anti-analysis.md`,
  `cslib-adversarial-verification.md`) is mandatory, not stylistic: an unprefixed override
  previously clobbered core's file at the shared path when two extensions both declared `"contracts"`
  in `provides.context`.
- **Confirmed prior-art closure, current state**: `build_hard_contracts_injection` (task 118) built
  the mechanism; `retire_routing_agents_hard_for_hard_contracts` (task 444) retired the former
  agent-level `routing_agents_hard` ladder entirely, collapsing `--hard` to dispatch the SAME agent
  as standard mode with ONLY the contract list differing. Today exactly two non-core extensions
  declare this block: `lean` (`hard_contracts.lean4`, three `replace:` + two additive) and `cslib`
  (`hard_contracts.cslib`, one `replace:` + one cross-extension additive referencing `lean`'s
  `lean4-context-hygiene.md`). `books` deliberately declares none -- a valid, documented choice, not
  a gap. No evidence was found of a distinct `deliver_hard_mode_contracts_across_extensions` task
  beyond these two closures; the dispatch's reference to that name is read as referring to this
  same two-extension delivery, not a third, separate task.

### `index.json` Merging and the `<leader>al` Loader Deploy Step (Outcome 5)

- The `<leader>al` loader is `lua/neotex/plugins/ai/shared/extensions/` (picker.lua UI, driven by
  `loader.lua`/`manifest.lua`/`merge.lua`) -- this is Nvim-plugin Lua code, outside `.claude/` and
  outside the `agent-system/extensions/**` source store proper; it is the mechanism that reads BOTH.
- **Context/docs categories** (`provides.context`, `provides.docs`): `M.copy_category`'s
  `entry_kind = "file_or_dir"` branch checks `vim.fn.isdirectory()` first (whole-directory-tree copy,
  the common case -- e.g. `"project/python"`), falling back to `vim.fn.filereadable()` for an
  individual file path.
- **`index-entries.json` merge** (`merge.lua`'s `append_index_entries()`): reads or initializes
  `.claude/context/index.json`, then for every incoming entry, **upserts by exact `path` match**
  (replace-in-place preserving array position if the path already exists, else append) -- the merge
  function itself does NOT validate schema shape (that is Rule T's separate, lint-time job); it
  tracks every added/updated path in a returned `{paths: [...]}` structure consumed on unload by
  `remove_index_entries_tracked()` for precise retraction. `version`/`generated` metadata fields are
  stamped once (`version`) and refreshed every write (`generated`).
- **`scripts` category flat-deploy model**: `provides.scripts` entries copy FLAT into
  `.claude/scripts/`, mixed with core's and every other loaded extension's scripts -- never into a
  nested `.claude/extensions/{name}/scripts/` (that path never exists in a deployed tree). This is
  the mechanical reason the lifecycle-hook and observer path-resolution-by-basename rules exist: a
  hook/observer declared without a matching flat `provides.scripts` entry resolves to a path the
  deploy never produces.
- **CLAUDE.md regeneration**: on load/unload, the loader concatenates every currently-loaded
  extension's `merge_targets.claudemd.source` file content, core first then others in sorted order,
  via `generate_claudemd()` -- `.claude/CLAUDE.md` is a wholly computed artifact, never hand-edited.

## Recommendations

- **Scaffold the new `typescript` extension on the `nix` precedent, not the `python`/`rust` floor.**
  `nix` is the smallest extension that already needs toolchain-presence detection
  (`nix-preflight.sh`) and surfaces detected toolchain facts to the dispatched agent
  (`nix-context.sh` via the `context_injection` hook) -- structurally identical to what a TypeScript
  extension needs for the detection matrix below (report which runtime/package-manager/test-runner
  combination was found, non-blocking if the toolchain is partially absent).
- **Declare `keyword_overrides.typescript`** modeled directly on `rust`'s entry: multi-word-biased
  keywords (`"typescript"`, `"tsconfig"`, `"tsc --noEmit"`, `".ts file"`) to avoid the bare-`"ts"`
  false-positive class task 210 already closed for the weak-signal table generally -- a bare `"ts"`
  keyword would be exactly the blunt, false-positive-prone lever the dev guide's `keyword_overrides`
  section warns against.
- **Give the new extension a REAL `routing_agents` block before considering `keyword_overrides`
  at all** (per the dev guide's explicit ordering rule) -- design task 620 owns this, but this
  research confirms the mechanical reason: a `keyword_overrides` key with no backing
  `routing_agents` entry resolves to an undispatchable `task_type`, which is strictly worse than
  falling through to `general`.
- **Decide `hard_contracts` is likely NOT needed** for a first cut, following `books`'s precedent:
  unless a TypeScript-specific H2/H3/H4 elaboration is judged non-duplicative of the generic core
  contracts, declaring nothing is the documented, valid default.
- **Split `web/context/project/web/domain/typescript-web.md`'s content along the generic/Astro-specific
  seam** (task 623's job, flagged here for continuity): the existing file is Astro-component-props-
  specific (interface `Props`, `HTMLAttributes`, Astro `tsconfig` presets) and does not currently
  cover ANY of the generic runtime/package-manager/test-runner detection matrix below -- confirming
  there is no existing overlap/duplication risk between what task 621 will create and what task 623
  will leave behind in `web`.

## Decisions

- Treat `agent-system/extensions/core/` copies of the READ FIRST docs as authoritative over the
  `.claude/` deployed mirrors, per `.claude/rules/source-store-deploy-boundary.md` -- all citations
  above resolve against the source-store paths.
- Treat the "prior art already closed" claims in the dispatch as **confirmed, not reinvented**: task
  118 + task 444 together fully account for the hard-contracts injection/retirement lineage, and task
  210 fully accounts for the keyword-override false-positive-hazard fix; no further archival digging
  was performed once each claim was corroborated against live source (manifest content, script logic,
  and the `task-type-detect.sh` header comment's own self-citation of the originating plan).
- Verify the 2026 toolchain matrix via live web search rather than relying on pretraining, given the
  dispatch's explicit "current (2026)" framing and the magnitude of what turned out to have changed
  (TS7 GA, ESLint v10, Bun default lockfile format, Vite 8/Rolldown) between this agent's training
  cutoff (January 2026) and the present date.

## TypeScript Toolchain Detection Matrix (2026) (Outcome 6)

Every row names the detection **signal** (file presence, lockfile name, `package.json` script name,
or devDependency key) rather than assuming a stack. Signals are listed in descending priority within
each category where more than one can apply simultaneously (e.g. an explicit `packageManager` field
beats lockfile inference).

### Runtimes

| Runtime | Primary signal | Secondary signal | 2026 note |
|---|---|---|---|
| Node.js | `package.json` present with no Bun/Deno-specific markers below | `.nvmrc` or `.node-version` file; `engines.node` in `package.json` | Default/fallback when no stronger signal fires. |
| Bun | `bun.lock` (text, default since Bun 1.2) or legacy `bun.lockb` (binary) at repo root | `bunfig.toml` present; `package.json`'s `"packageManager": "bun@..."` | `bun.lock` supersedes `bun.lockb` as the primary signal; a repo with only `bun.lockb` is on a pre-1.2 or unmigrated Bun project. |
| Deno | `deno.json`/`deno.jsonc` present | `deno.lock`; import specifiers using bare `npm:`/`jsr:`/full URLs in source | As of the Feb-2026-updated Deno 2 docs, a `package.json`+`deno.json` project defaults to **manual** `node_modules` (no auto-install) unless `deno.json`'s `nodeModulesDir` is explicitly `"auto"` -- do not assume `node_modules` existence implies non-Deno. |

### Package Managers (via lockfile)

| Package manager | Primary signal | Secondary signal |
|---|---|---|
| (any) | `package.json`'s `"packageManager"` field (corepack-pinned, e.g. `"pnpm@9.1.0"`) | Highest-priority signal when present -- authoritative, not inferred. |
| npm | `package-lock.json` | `npm-shrinkwrap.json` (rare) |
| pnpm | `pnpm-lock.yaml` | `pnpm-workspace.yaml` (monorepo marker) |
| yarn (classic, v1) | `yarn.lock` with no `.yarnrc.yml` | `"yarn.lock" v1` header comment inside the file |
| yarn (Berry, v2+) | `yarn.lock` + `.yarnrc.yml` present | `.yarnrc.yml`'s `yarnPath` field pins the exact Berry release |
| bun | `bun.lock` (text, default) or `bun.lockb` (legacy binary) | `bunfig.toml` |

### Test Runners

| Test runner | Primary signal | Secondary signal |
|---|---|---|
| `node:test` (built-in) | `package.json` test script invoking `node --test` | Source files importing `node:test`/`node:assert`; no devDependency required (built into Node). |
| Vitest | `vitest.config.{ts,js,mts,mjs}` present, OR a `test` block inside `vite.config.ts` | `vitest` in `devDependencies`; test script running `vitest run` |
| Jest | `jest.config.{js,ts,cjs,mjs}` present, OR a `"jest"` key in `package.json` | `jest`/`ts-jest`/`babel-jest` in `devDependencies` |
| `bun:test` (built-in) | `package.json` test script invoking `bun test` | Source files importing `bun:test`; no devDependency required (built into Bun) |

### Typecheck / Build

| Tool | Primary signal | Secondary signal | 2026 note |
|---|---|---|---|
| `tsc` (standard or native) | `tsconfig.json` present + `typescript` in `devDependencies`/`dependencies` | `package.json` script named `typecheck`/`check` running `tsc --noEmit` | **As of `typescript@7.x` (GA July 2026), `tsc` IS the Go-native compiler** -- there is no separate binary to detect; check the resolved `typescript` version (`^7`) to know whether the native-speed path is already active, rather than looking for a distinct `tsgo` signal. |
| `tsgo` / native-preview (pre-7.0 opt-in only) | `@typescript/native-preview` in `devDependencies` | A script invoking the bare `tsgo` command | This signal is now legacy: the nightly-only `@typescript/native-preview` channel is for bleeding-edge builds past the mainlined `typescript@7.x`, not the primary native-compiler path any more. |
| esbuild | `esbuild` in `devDependencies` | `esbuild.config.*`, or esbuild invoked transitively via `vite`/`vitest`/`tsup` (do not double-count) |
| tsup | `tsup.config.{ts,js,mjs}` present | `tsup` in `devDependencies`; build script running `tsup` |
| rolldown | Explicit `rolldown.config.{ts,js,mjs}` OR `rolldown` in `devDependencies` | `ROLLDOWN_EXPERIMENTAL` env var reference (legacy opt-in signal, pre-Vite-8) | **As of Vite 8 (stable March 2026), Rolldown is Vite's default bundler** -- a plain `vite` dependency with no separate `rolldown` entry already implies Rolldown is in use; only flag "rolldown" as its own distinct tool when there is no `vite` dependency at all (standalone Rolldown usage) or an explicit override. |
| swc | `.swcrc` present | `@swc/core` in `devDependencies`; Jest config's `transform` referencing `@swc/jest` |

### Lint / Format

| Tool | Primary signal | Secondary signal | 2026 note |
|---|---|---|---|
| ESLint (flat config) | `eslint.config.{js,mjs,cjs,ts}` present | `eslint` in `devDependencies` | **As of ESLint v10 (Feb 2026), legacy `.eslintrc*` is unsupported entirely** (`ESLINT_USE_FLAT_CONFIG` env var no longer honored) -- a repo with ONLY a `.eslintrc*` file and no `eslint.config.*` is necessarily pinned to ESLint <=9 (end-of-life Aug 2026); do not treat `.eslintrc*` presence alone as "uses ESLint" without also checking the installed version. |
| Biome | `biome.json`/`biome.jsonc` present | `@biomejs/biome` in `devDependencies` | Biome 2 adds type-aware lint rules without depending on the TypeScript compiler -- its presence does not imply a `tsc`/`tsgo` dependency for linting purposes specifically. |
| oxlint | `.oxlintrc.json` present | `oxlint` in `devDependencies`; a script invoking `oxlint` | Stable (v1, 2025) but still commonly run as a fast pre-pass alongside ESLint rather than a full replacement -- detect as additive, not necessarily exclusive, with ESLint. |
| Prettier | `.prettierrc*` (any extension) present, OR a `"prettier"` key in `package.json` | `prettier` in `devDependencies` |

### Module Resolution Modes (tsconfig-level)

| Mode | Primary signal |
|---|---|
| `bundler` | `tsconfig.json`'s `compilerOptions.moduleResolution` == `"bundler"` -- the expected mode for any bundler-fronted project (Vite/esbuild/webpack/rolldown) that does not need explicit import extensions. |
| `node16`/`nodenext` | `compilerOptions.module`/`moduleResolution` == `"node16"` or `"nodenext"`, typically paired with `package.json`'s `"type": "module"`. |
| `nodenext` with `.js` specifiers | Same as above, PLUS relative import statements in `.ts` source ending in literal `.js` (TS resolves the `.js` specifier back to the sibling `.ts` file under `nodenext`'s ESM rules) -- grep source for `from ['"]\./.*\.js['"]` as the concrete signal distinguishing this sub-case from plain `nodenext` without the specifier convention. |

## Risks & Mitigations

- **Risk**: a detection script that hardcodes "if `typescript` is present, look for a separate `tsgo`
  binary" will be silently wrong for any `typescript@7.x` project, since `tsc` itself IS the native
  binary now. **Mitigation**: the matrix above makes version-gating (`typescript` semver `^7`) the
  primary signal for "native-speed tsc already active," not a separate tool-presence check.
- **Risk**: treating `.eslintrc*` presence as sufficient evidence of "uses ESLint" will misclassify a
  pre-v10-pinned project as using flat config when it is not (or vice versa for a v10 project that
  still carries a stale, unused `.eslintrc*` file mid-migration). **Mitigation**: the matrix pairs the
  config-file signal with an explicit version-check caveat.
- **Risk**: a bare `"ts"` or `"typescript"` single-word `keyword_overrides` entry for the new
  extension would reproduce exactly the false-positive class task 210 already closed for the
  weak-signal table (a word that appears in unrelated prose, e.g. "let's typeset this in LaTeX" does
  NOT contain "typescript," but a shorter/blunter token risks exactly this). **Mitigation**:
  Recommendations above call out multi-word-biased keyword phrasing explicitly; task 620 (design)
  should ground-truth candidate keywords against the same false-positive discipline before finalizing.
- **Risk (carried-figure obligation)**: the "two non-core extensions declare `hard_contracts`" count
  and the "no third `deliver_hard_mode_contracts_across_extensions` task" negative-existence claim
  above are both enumerations presented as complete. **Mitigation/discharge**: both were verified by
  a direct `grep -l "hard_contracts" agent-system/extensions/*/manifest.json` sweep (returned exactly
  `lean` and `cslib`, nothing else) and a `ls specs/archive/ | grep -i hard` sweep (no directory name
  containing `deliver_hard_mode` or `hard_mode_contracts` exists) -- both commands are reproducible
  verbatim against the live corpus, discharging the completeness obligation rather than deferring it.

## Context Extension Recommendations

- **Topic**: 2026 TypeScript toolchain detection signals (runtime/package-manager/test-runner/
  build/lint/module-resolution).
- **Gap**: No existing context file in `agent-system/extensions/web/context/project/web/` or
  elsewhere in the source store documents a cross-tool detection matrix of this kind -- `web`'s
  existing `domain/typescript-web.md` is Astro-component-specific and does not cover generic Node/
  Bun/Deno runtime detection, package-manager-via-lockfile detection, or the 2026-current tool
  landscape (TS7/ESLint10/Bun-lock/Vite8-Rolldown) at all.
- **Recommendation**: task 621 (implementation) should materialize this report's detection-matrix
  section directly into the new `agent-system/extensions/typescript/context/project/typescript/domain/
  toolchain-detection.md` (or equivalent path design task 620 settles on), rather than re-deriving it
  from scratch -- this report is the primary source for that content, written against a verified
  current (Nov 2026) toolchain snapshot.

## Appendix

### Search Queries Used (WebSearch)

- `tsgo TypeScript native preview 2026 release status Microsoft`
- `bun.lock text lockfile format 2026 bun package manager detection`
- `rolldown-vite default bundler Vite 2026 stable`
- `ESLint flat config eslintrc removed version 2026`
- `oxlint stable biome 2.0 2026 javascript linter formatter adoption`
- `Deno 2 2026 package.json node_modules compatibility deno.json detection`

### Key Source Files Read

- `agent-system/extensions/core/context/guides/extension-development.md`
- `agent-system/extensions/core/docs/guides/creating-extensions.md`
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md`
- `agent-system/extensions/core/context/guides/hard-mode-routing.md`
- `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md`
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh`
- `agent-system/extensions/core/scripts/lib/task-type-detect.sh`
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (Rules T, R, U, and the
  README/EXTENSION.md `check_file` calls)
- `agent-system/extensions/core/context/patterns/context-discovery.md`
- `agent-system/extensions/{python,rust,web,nix,lean}/manifest.json` (full diff)
- `lua/neotex/plugins/ai/shared/extensions/{manifest,merge}.lua`
- `agent-system/extensions/web/context/project/web/domain/typescript-web.md`

### Sources (WebSearch)

- [TypeScript 7.0 RC moves Microsoft's Go rewrite into the mainline compiler](https://visualstudiomagazine.com/articles/2026/06/22/typescript-7-0-rc-moves-microsofts-go-rewrite-into-the-mainline-compiler.aspx)
- [Microsoft Gets Real on Native TypeScript Remake](https://visualstudiomagazine.com/Articles/2025/12/02/Microsoft-Gets-Real-on-Native-TypeScript-Remake.aspx)
- [Bun lock text lockfile](https://bun.sh/blog/bun-lock-text-lockfile)
- [Bun lockfile docs](https://bun.sh/docs/pm/lockfile.md)
- [Announcing Vite 8](https://vite.dev/blog/announcing-vite8.html)
- [Announcing Rolldown 1.0](https://voidzero.dev/posts/announcing-rolldown-1-0)
- [ESLint v10.0.0 released](https://eslint.org/blog/2026/02/eslint-v10.0.0-released/)
- [Oxlint v1 released](https://www.infoq.com/news/2025/08/oxlint-v1-released)
- [Biome 2.0 changelog](https://biomejs.dev/internals/changelog/version/2-0-0...latest/)
- [Deno runtime configuration docs](https://docs.deno.com/runtime/fundamentals/configuration.md)
- [Deno Node.js migration guide](https://docs.deno.com/runtime/reference/migration_guide/)
