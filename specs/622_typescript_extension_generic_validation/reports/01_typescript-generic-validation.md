# Research Report: Task #622

**Task**: 622 - Validate the typescript extension's generic toolchain detection against a real no-tsconfig node:test repository
**Started**: 2026-11-14T00:12:00Z
**Completed**: 2026-11-14T00:49:54Z
**Effort**: medium
**Dependencies**: Task 621 (completed)
**Sources/Inputs**:
- Live end-to-end load of the `typescript` extension into `/home/benjamin/Projects/Sapience/sf1-engine`
- Direct execution of the deployed `typescript-verify.sh` hook against that repo's real TypeScript codebase
- Codebase inspection: `agent-system/extensions/typescript/**`, `.claude/scripts/skill-base.sh`, `.claude/scripts/command-gate-out.sh`
**Artifacts**:
- This report: `specs/622_typescript_extension_generic_validation/reports/01_typescript-generic-validation.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The target repository's profile was confirmed exactly as specified: ESM (`"type": "module"`),
  test script `node --test test/*.test.ts`, no `tsconfig.json` anywhere, no bundler, no
  lockfile, 86 `*.test.ts` files — all at `sf1-v2/opencode-plugin/`, not at the repo root.
- Every piece of the extension's **detection logic itself** (lockfile-priority fallback to npm,
  typecheck-script/`tsconfig*` SKIP, test-script presence check, npm-placeholder rejection) is
  correct and generic: run with cwd set to the directory that actually holds `package.json`, the
  hook correctly SKIPs typecheck and correctly runs `npm run test` -> `node --test
  test/*.test.ts`.
- **The extension fails the PASS CONDITION as currently wired**, for a different, more basic
  reason: the verification-stage lifecycle hook is invoked with cwd fixed at the repo root (no
  `cd` anywhere in the call chain), and the hook script only ever checks `package.json` relative
  to its own cwd. Because sf1-engine's actual TypeScript project lives one directory down
  (`sf1-v2/opencode-plugin/package.json`), the hook silently prints `SKIP: no package.json
  found` and exits 0 **without ever discovering the TypeScript project exists** — the gate never
  runs at all.
- This is a structural, generic gap (reproducible on any repo whose Node/TS project is not at
  repo root — monorepos, nested app/lab subdirectories), not something specific to sf1-engine.
  Recommended approach: a bounded, vendor-dir-excluded recursive search for `package.json`
  beneath cwd when none exists directly at cwd, per Recommendations below.
- No repo-specific content was added to the extension to make this pass; the defect and its
  recommended fix are both expressed entirely in terms of the hook's own detection logic.

## Context & Scope

Task 621 implemented the `typescript` extension in the source store
(`agent-system/extensions/typescript/`), including a verification-stage lifecycle hook
(`scripts/typescript-verify.sh`) whose detection logic was designed to be strictly generic:
lockfile-priority package-manager detection, a declared-script-or-`tsconfig*`-fallback typecheck
check, and a test-script presence check with npm-placeholder rejection. Task 622 is the
falsifiability check on that grounding decision: load the extension, unmodified, into a real
external repository never seen during its design, and determine whether the detection logic
holds up against a deliberately unusual profile (ESM, no tsconfig, raw `node --test`, no
bundler) — without adding any sf1-engine-specific content to the extension.

**In scope**: the extension's detection logic and the lifecycle-hook invocation path that
delivers it a working directory. **Out of scope**: sf1-engine's own test health (29 of 560
subtests in its lab test suite failed on this run, e.g. an assertion referencing a git commit
hash absent from this clone, and a timing-sensitive picker-warmup assertion — both pre-existing
properties of that repo's own code, unrelated to TypeScript-project detection, and not touched).

## Findings

### Codebase Patterns

- `skill_run_extension_hook` (`.claude/scripts/skill-base.sh`, mirrored identically in
  `agent-system/extensions/core/scripts/skill-base.sh`) resolves the hook script by basename
  under `.claude/scripts/` and invokes it as `"$hook_path" "$task_number" "$task_type"
  "$task_dir" "$session_id" "$operation"` with **no `cd` anywhere in the function body**.
- Its sole caller for the `verification` stage, `command-gate-out.sh` line 342 (mirrored in
  `agent-system/extensions/core/scripts/command-gate-out.sh`), likewise contains **no `cd`
  statement anywhere in the file** (checked via `grep -n '^cd \| cd "'` across the whole
  script; zero matches). Both call sites were located via `grep -rn
  'skill_run_extension_hook "verification"'` across `.claude/scripts/` and
  `agent-system/`; the two deployed-vs-source-store pairs are identical mirrors of the same two
  logical call sites, not independent ones.
- Consequence: the verification hook's cwd is whatever cwd the overall command/skill lifecycle
  is already running with — the project root — never `$task_dir` (a `specs/NNN_slug/`
  task-management directory, itself not useful here either) and never any
  code-location-specific directory.
- `typescript-verify.sh`'s own detection starts cold at `[ -f "pnpm-lock.yaml" ]` /
  `... yarn.lock` / `... package-lock.json` / `... bun.lockb` / `... package.json`, all
  relative to cwd, with no fallback search below cwd. `$TASK_DIR` ($3) is received but
  deliberately unused (the script's own `SC2034` comment: "this hook's own detection logic needs
  none of them directly").
- `agent-system/extensions/typescript/context/project/typescript/tools/package-manager-detection.md`
  documents "No `package.json` At All" as a normal, expected terminal outcome at "this
  location" — i.e. the doc's own stated design is single-location detection, with no discussion
  of a nested/monorepo layout at all. The implementation matches the doc; the doc simply never
  considered the nested-project case this task was built to probe.
- No other extension in `agent-system/extensions/*/manifest.json` declares a `verification`
  hook (`grep -rl '"verification"' agent-system/extensions/*/manifest.json` returns only
  `typescript/manifest.json`), so there is no existing sibling pattern for directory-scoping a
  verification hook to borrow from.

### External Resources

Not applicable — this validation is entirely a live, local, end-to-end exercise against a real
repository and the extension's own source; no external documentation was consulted.

### Live Validation Procedure and Results

1. **Loaded the extension** into the target repo via the same headless-manager mechanism the
   test harness `test-mcp-merge-target.sh` uses, run from this repo (the real source store):
   ```
   nvim --headless -c "lua local ext_config = require('neotex.plugins.ai.shared.extensions.config'); \
     local ext_init = require('neotex.plugins.ai.shared.extensions.init'); \
     local manager = ext_init.create(ext_config.claude()); \
     local ok, err = manager.load('typescript', { project_dir = '/home/benjamin/Projects/Sapience/sf1-engine', confirm = false }); \
     print('LOAD_RESULT ok=' .. tostring(ok) .. ' err=' .. tostring(err))" -c "qa!"
   ```
   Result: `LOAD_RESULT ok=true err=nil`. `sf1-engine/.claude-extensions.json` gained a
   `typescript` entry (`source_dir` pointing at this repo's `agent-system/extensions/typescript`,
   `status: active`) alongside the pre-existing `core`, `python`, `sapience` entries; all 16
   `installed_files` (agents, skill docs, rules, context, the contract, and
   `.claude/scripts/typescript-verify.sh`) landed under `sf1-engine/.claude/` exactly as declared
   in the extension's manifest.
2. **Confirmed the target profile** by direct inspection of
   `sf1-engine/sf1-v2/opencode-plugin/`: `package.json` has `"type": "module"` and
   `"scripts": {"test": "node --test test/*.test.ts", "bench": "node bench/ttft.ts"}`; no
   `tsconfig*.json` anywhere under the repo (`find ... -iname "tsconfig*.json"` returns nothing);
   no lockfile anywhere in the repo; `ls test/*.test.ts | wc -l` = 86, matching the task
   description exactly. There is no `package.json` at the repo root at all.
3. **Ran the deployed hook from the repo root** (the cwd it is actually invoked with in the real
   lifecycle):
   ```
   cd /home/benjamin/Projects/Sapience/sf1-engine && \
     bash .claude/scripts/typescript-verify.sh 622 typescript specs/dummy sess_test preflight
   ```
   Output: `[typescript-verify] SKIP: no package.json found -- no Node/TypeScript project in
   scope, nothing to verify` / `summary: ran_pass=0 ran_fail=0 skipped_no_command=1`. This is the
   PASS CONDITION failure: the gate reports "nothing to verify" when a 86-suite TypeScript test
   project in fact exists in the repo.
4. **Ran the identical, unmodified hook with cwd set to the actual project directory**
   (`sf1-engine/sf1-v2/opencode-plugin/`) to isolate whether the detection *logic* itself (as
   opposed to the invocation site) is sound:
   - Typecheck sub-check: `SKIP: no tsconfig.json and no typecheck script found -- nothing to
     verify` — correct, since none exists.
   - Test sub-check: package-manager resolved to `npm` (no lockfile present, correct per the
     documented "No Lockfile, But a `package.json` Exists -> default to npm" rule); ran `npm run
     test` -> `node --test test/*.test.ts`; 531 subtests passed, 29 failed (pre-existing,
     environment/timing-dependent failures in sf1-engine's own lab suite, e.g. one assertion
     shelling out to a git commit hash not present in this clone, and one picker-warmup timing
     assertion — neither related to TypeScript-project detection); hook classified this
     correctly as `test finding: ran_fail (npm run test)`.
   - Final summary: `ran_pass=0 ran_fail=1 skipped_no_command=1` — the exact three-state outcome
     vocabulary the hook's own header describes, applied correctly to this profile.

## Recommendations

- **Give the detection logic a bounded fallback search, not a cwd change at the call site.**
  Changing where `skill_run_extension_hook`/`command-gate-out.sh` `cd` to before invoking the
  hook is the wrong layer to fix this in: there is no generic, repo-independent directory to
  `cd` into (the task's `$task_dir` is a `specs/NNN_slug/` management directory, not a code
  location, and no other signal available at that call site identifies the project root for an
  arbitrary repo). The fix belongs entirely inside `typescript-verify.sh`'s own detection,
  exactly where the task's HARD CONSTRAINT points: `agent-system/extensions/typescript/scripts/typescript-verify.sh`.
- **Concrete shape**: at the top of the script, after the existing cwd-relative lockfile/
  `package.json` checks find nothing, fall back to a bounded `find . -maxdepth <N> -name
  package.json -not -path '*/node_modules/*' -not -path '*/.git/*'` (excluding other common
  vendor/build directories such as `dist`, `build`, `.next`, `vendor` as they are discovered to
  matter) and re-run the same lockfile-priority/typecheck/test detection relative to each
  directory found, aggregating `ran_pass`/`ran_fail`/`skipped_no_command` across all of them
  rather than only the first. This preserves the current fast, correct, zero-cost path for the
  common single-root-package.json case (no `find` is needed when `package.json` already exists
  at cwd) while closing the nested-project gap this task exposed, and introduces no sf1-engine-
  specific knowledge — a repo-root `find` bounded by vendor-directory exclusion is exactly as
  generic as the existing lockfile-priority table.
- **Verified against the live corpus, not merely plausible**: this exact recommendation was
  re-derived from, and checked directly against, the live failure this task reproduced (the
  `find`-based fallback, run manually from the repo root during this validation, does locate
  `sf1-v2/opencode-plugin/package.json` and nothing else under `sf1-engine`), rather than being
  proposed from the detection-logic reading alone.
- Treat this as the Task 622 finding to carry into the plan phase: the fix is scoped,
  mechanical, and entirely contained to the one hook script; no other extension file needs to
  change.

## Decisions

- Validated the target repository (`sf1-engine`) and target profile
  (`sf1-v2/opencode-plugin/`) exactly as the task dispatch specified, rather than substituting a
  different repo or a synthetic fixture — the whole point of a falsifiability check is an
  external, previously-unseen repo.
- Left the `typescript` extension loaded in `sf1-engine` rather than unloading it after the
  validation run. `sf1-engine`'s own `git status` shows `.claude/`, `.claude-extensions.json`,
  and `.syncprotect` were already untracked before this load (consistent with
  `source-store-deploy-boundary.md`'s framing of a deployed `.claude/` tree as a disposable,
  regenerable deploy artifact) — the load introduced no git-tracked diff in that repository, and
  nothing in the dispatch asked for a revert.
- No change was made to `agent-system/extensions/typescript/**` in this research pass. The HARD
  CONSTRAINT ("any detection defect this exposes is fixed in the extension's own source-store
  files... never by special-casing the repo") governs whoever performs the fix; per this
  project's standard research -> plan -> implement lifecycle, the fix itself is left to the
  subsequent plan/implement phases, informed by the concrete, re-derived recommendation above.

## Risks & Mitigations

- **Risk**: a `find`-based fallback could be slow or noisy on a very large monorepo with many
  nested `package.json` files (e.g. inside numerous small internal packages).
  **Mitigation**: bound the search depth and explicitly exclude `node_modules`/`.git` (and other
  vendor/build directories as needed); aggregate rather than fail on multiple matches, and cap
  the number of projects verified if this proves necessary in practice.
- **Risk**: aggregating pass/fail/skip across multiple discovered projects could obscure which
  specific project failed. **Mitigation**: prefix each sub-check's echo lines with the relative
  directory of the `package.json` being checked (the script already prefixes every line with
  `[typescript-verify]`; extending that prefix with the relative path costs nothing extra).
- **Risk (already realized and out of scope)**: sf1-engine's own lab test suite has 29
  pre-existing failing subtests unrelated to this task. **Mitigation**: none needed from this
  task — correctly reporting `ran_fail` for a repo whose tests are genuinely failing is the
  hook working as intended, not a defect.

## Context Extension Recommendations

- **Topic**: nested/monorepo package.json discovery for toolchain-detection lifecycle hooks.
- **Gap**: `agent-system/extensions/typescript/context/project/typescript/tools/package-manager-detection.md`
  documents only single-location (cwd-relative) detection and treats "no package.json at this
  location" as an unconditional terminal/normal outcome, with no guidance for a nested project
  layout.
- **Recommendation**: once the plan/implement phases land the bounded-search fix recommended
  above, update that same doc with a new "No `package.json` At cwd, But One Exists Below" section
  describing the bounded-search fallback and its vendor-directory exclusions, so the human-
  readable companion stays in sync with the mechanical detection logic exactly as its own header
  promises.

## Appendix

### Search Queries / Commands Used

- `grep -n "622" specs/TODO.md` / task-622 TODO entry read in full
- `find agent-system/extensions/typescript -type f`
- `cat agent-system/extensions/typescript/scripts/typescript-verify.sh`
- `python3 -c "..."` reading `sf1-engine/.claude-extensions.json`'s `extensions` keys and
  `source_dir` values
- `grep -rn "manager.load(" .claude/scripts/ lua/` (located the headless-load mechanism via
  `test-mcp-merge-target.sh`'s own usage)
- `nvim --headless -c "lua ... manager.load('typescript', ...)" -c "qa!"` (the actual load)
- `find . -iname "tsconfig*.json"`, `ls sf1-v2/opencode-plugin/test/*.test.ts | wc -l`,
  `cat sf1-v2/opencode-plugin/package.json` (target-profile confirmation)
- `bash .claude/scripts/typescript-verify.sh 622 typescript specs/dummy sess_test preflight`
  (run twice: once from the repo root, once from `sf1-v2/opencode-plugin/`)
- `grep -rn 'skill_run_extension_hook "verification"' .claude/scripts/ agent-system/`
- `grep -n "^cd \|  cd \| cd \"" .claude/scripts/command-gate-out.sh` (zero matches)
- `grep -rl '"verification"' agent-system/extensions/*/manifest.json` (confirms typescript is
  the only extension with this hook)

### References

- `agent-system/extensions/typescript/manifest.json`
- `agent-system/extensions/typescript/scripts/typescript-verify.sh`
- `agent-system/extensions/typescript/context/project/typescript/tools/package-manager-detection.md`
- `.claude/scripts/skill-base.sh` (`skill_get_extension_dir`, `skill_run_extension_hook`)
- `.claude/scripts/command-gate-out.sh` (verification-stage call site)
- `/home/benjamin/Projects/Sapience/sf1-engine/.claude-extensions.json`
- `/home/benjamin/Projects/Sapience/sf1-engine/sf1-v2/opencode-plugin/package.json`
