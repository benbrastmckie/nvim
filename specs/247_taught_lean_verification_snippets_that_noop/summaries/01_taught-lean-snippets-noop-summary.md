# Implementation Summary: Task #247

- **Task**: 247 - Taught Lean verification snippets that no-op
- **Status**: [COMPLETED]
- **Started**: 2026-09-22T01:25:00Z
- **Completed**: 2026-09-22T02:45:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: 221, 173 (both landed; line numbers re-derived against the current tree)
- **Artifacts**: plans/01_taught-lean-snippets-noop.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed two independent taught-snippet defects in `agent-system/extensions/lean/` (the source
store — never `.claude/**`, which is a disposable deploy artifact). Half 1 corrected every
`lake-build-guard.sh` invocation whose first post-`--` token was a bare module name instead of an
allowlisted lake subcommand (the guard exits 77 without building). Half 2 replaced the hardcoded
`Theories/` scan root — which silently scans nothing and reports a clean result in any consuming
repo where that literal directory does not exist — with a single resolver script,
`lean-src-roots.sh`, that derives real source roots from the consuming repo's `lakefile.toml` and
fails loudly (non-zero exit, naming every root tried) when nothing resolves. `lean-sorry-census.sh`
independently stopped exiting 0 on a missing or empty target. Verified end-to-end in
`~/Projects/BimodalLogic` (planted-and-detected sorry) and redeployed into that consuming repo
plus this repo's own `.claude/`.

## What Changed

- `agent-system/extensions/lean/rules/lean4.md` — fixed the broken `-- Module.Name` guard vector
  (now `-- build Module.Name`); rewrote both `-- <lake args>` placeholders as
  `-- <lake-subcommand> [args]` with a concrete `# e.g. -- build Module.Name` comment (D1)
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — fixed the broken
  `-- ModuleName 2>&1` guard vector; added a "resolve source roots" step to Final Verification
  Stage 6; routed the census, vacuous-def grep, axiom grep, plan-compliance prose, and both
  comparator-preflight blocks through `"${lean_roots[@]}"`; changed the `sorry_inventory` JSON
  sample's `"file"` value from `"Theories/Foo.lean"` to the neutral `"<src-root>/Foo.lean"` (D7)
- `agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md` — fixed the broken
  `-- "$module"` guard vector (now `-- build "$module"`)
- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` — rewrote the
  canonical `-- <lake args>` placeholder the same way as lean4.md (D1)
- `agent-system/extensions/lean/scripts/lean-src-roots.sh` — new. Resolves Lean source roots from
  `lakefile.toml` `[[lean_lib]]` entries (Lake defaults applied: `srcDir` "." , `roots` `[name]`;
  `globs` best-effort mapped), falling back to `LEAN_SRC_ROOTS` only when no `lakefile.toml`
  exists. Exits non-zero, naming every root tried, on: no lakefile and no env (65); unparseable
  TOML or missing python3 (66); zero `lean_lib` entries (67); zero existing roots (68); zero
  `.lean` files across existing roots (69, the load-bearing loud-failure case)
- `agent-system/extensions/lean/scripts/tests/test-lean-src-roots.sh` — new. 10 fixtures (A-I)
  covering BimodalLogic-shaped and cslib-shaped lakefiles, `--default-targets`, both env-fallback
  paths, and every failure code; all passing
- `agent-system/extensions/lean/manifest.json` — registered both new files under
  `provides.scripts`
- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` — a nonexistent target is now fatal
  (exit 65, was warn-and-skip); zero `.lean` files collected is now fatal (exit 66, was
  `sorry_count: 0` / exit 0); usage comment rewritten to the guarded resolver-consumption shape,
  no literal `Theories/`
- `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` — added Fixtures J
  (nonexistent target), K (existing-but-empty target — the mutation-check fixture), and L
  (existing target, real files, no sorry — proves "clean" stays distinct from "nothing scanned");
  existing Fixtures A-I unchanged, 17/17 passing
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` — added a "resolve source
  roots" step (Step 0) at the top of Final Verification Steps; routed the sorry census,
  vacuous-def grep, axiom grep, plan-compliance grep/echo text, and both comparator-preflight
  blocks through `"${lean_roots[@]}"`
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md` and
  `skills/skill-lean-implementation-hard/SKILL.md` — Stage 8/9 git-commit staging now resolves
  source roots first (guarded `||` capture, exit 1 on resolver failure — never commits without
  the real sources) instead of hardcoding `-- "Theories/"`
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` — reworded
  the compliance-check description from "a name-existence grep over `Theories/`" to "a
  name-existence grep over the roots resolved by `lean-src-roots.sh`"

## Decisions

- **D1**: Placeholder guard invocations rewritten as `-- <lake-subcommand> [args]` plus a
  concrete `-- build Module.Name` example comment, rather than expanding to one fixed subcommand
  (callers also use `env`, not only `build`).
- **D2**: A new standalone script (`lean-src-roots.sh`), not a function inside
  `lean-sorry-census.sh` and not a bare `$LEAN_SRC_ROOTS` variable — the non-census consumers
  (raw greps, comparator-preflight discovery, commit-staging) needed a shared resolver that isn't
  itself the census.
- **D3**: `lakefile.toml` `[[lean_lib]]` entries are authoritative, with Lake's own default rules
  applied. All entries are used by default (covers library and test sources); `--default-targets`
  restricts to the package's declared `defaultTargets`.
- **D4**: `LEAN_SRC_ROOTS` is a fallback consulted only when no `lakefile.toml` exists; if a
  lakefile exists, the env var is ignored with a stderr notice — exactly one convention live at a
  time.
- **D5**: Loud failure lives in both the resolver (exit 65/66/67/68/69, all naming what was
  tried) and the census (exit 65 nonexistent target, exit 66 zero `.lean` files) — anyone calling
  the census directly, not only through the resolver, still gets the loud-failure guarantee.
- **D6**: `lake-build-guard.sh`'s exit-77 message (suggesting it name `-- build Module.Name`
  rather than only "a subcommand is required") was NOT edited here — that file belongs to a
  different task (#173 in the original filing). The suggestion is recorded here, in this summary,
  for whoever owns that file next: consider making the exit-77 message name the expected
  `-- <subcommand> [args]` shape explicitly.
- **D7**: Prose `Theories/` sites in `context-hygiene.md`, `anti-analysis.md`,
  `lean-research-hard-agent.md`, and `lean-implementation-hard-agent.md:117` were left unchanged
  — they are illustrative read-budget/phase-scope prose, not executable checks that could
  silently no-op. The one JSON sample (`lean-implementation-hard-agent.md`'s `sorry_inventory`
  example) was neutralized to `"<src-root>/Foo.lean"` so a sample output does not re-teach the
  literal.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (documentation/script fixes, not a Lean build)
- Tests: Passed — `test-lean-src-roots.sh` 10/10, `test-lean-sorry-census.sh` 17/17,
  `test-lean-challenge-snapshot.sh` 14/14, `test-lean-comparator-run.sh` 22 passed / 0 failed / 1
  pre-existing environment skip (sibling-suite regression check confirms
  `test-lean-sorry-census.sh` still exits 0)
- Files verified: Yes

**Acceptance criteria** (from the dispatch):
1. Exhaustive guard-vector audit: every post-`--` first token across the extension is `build`,
   `env`, or the placeholder `<lake-subcommand>` — all allowlisted or placeholder-conformant.
   `git diff --stat -- agent-system/extensions/core/` is empty.
2. `grep -rn "Theories/" agent-system/extensions/lean/ | grep -v scripts/tests/` lists only the
   D7 prose sites (`context-hygiene.md:34,69`, `anti-analysis.md:57`,
   `lean-research-hard-agent.md:135`, `lean-implementation-hard-agent.md:117`) plus
   `lean-src-roots.sh`'s own explanatory header comment describing the historical defect it
   fixes.
3. Ran (not asserted) the resolver and the census against a nonexistent root and an
   existing-but-empty root: resolver exits 68/69, census exits 65/66, both naming the root(s)
   tried on stderr.
4. In `~/Projects/BimodalLogic`: resolved default-target roots (`FormalSystem`,
   `FormalSystem.lean`) via the unmodified taught snippet shape; census reported
   `sorry_count: 0` beforehand; planted `FormalSystem/ZzPlantedSorry.lean` with a real sorry;
   census correctly reported `sorry_count: 1` naming the file and line; deleted the planted file;
   `git status --porcelain` matched the exact pre-test baseline.
5. Redeployed into `~/Projects/BimodalLogic` via `deploy-headless.sh` (default, non-destructive
   resync mode): `verify-deploy` reported PASS (14 checks, 0 failures). Confirmed
   `.claude/scripts/lean-src-roots.sh` exists there, `.claude/agents/lean-implementation-agent.md`
   has zero `Theories/` occurrences, and `.claude/rules/lean4.md` shows `-- build Module.Name`.
   Also redeployed this repo's own `.claude/` (the lean extension is not loaded in this repo's own
   `.claude-extensions.json` — it is the source-store repo, not a lean consumer — so its own
   `.claude/` carries no lean files to check). That redeploy's inline `verify-deploy --skip-slow`
   reported one pre-existing, unrelated failure: gate 17 (scoped-commit boundary lint) flags a
   bare `git commit -m "true"` at
   `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh:152`, a file this task
   never touched, under `agent-system/extensions/core/`, which this task's MUST NOT list forbids
   editing. Confirmed pre-existing via `git blame` (unrelated to any commit made in this task) and
   reported here per the observation-duty contract rather than fixed out of scope.

## Impacts

- Every agent/skill that runs Lean final verification now scans the consuming repo's REAL source
  roots instead of a literal that may not exist there — closing a verification instrument that
  could pass silently over an empty scan.
- Every taught guard invocation in the extension now launches an actual `lake build` instead of
  exiting 77 silently.
- `lean-sorry-census.sh` callers outside this extension that pass a target directly (not through
  the resolver) now get the same loud-failure guarantee for a missing/empty target.

## Follow-ups

- D6: consider making `lake-build-guard.sh`'s exit-77 message name the expected
  `-- <subcommand> [args]` shape explicitly (belongs to the guard's owning work, not this task).
- Observed, unrelated, pre-existing: this repo's own `verify-deploy --skip-slow` fails gate 17
  (scoped-commit boundary lint) on a bare `git commit -m "true"` at
  `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh:152`. Predates this task
  (confirmed via `git blame`); out of scope here (this task's MUST NOT list forbids editing
  `agent-system/extensions/core/`). Flagged for whoever owns that file next.

## References

- Plan: `specs/247_taught_lean_verification_snippets_that_noop/plans/01_taught-lean-snippets-noop.md`
- Report: `specs/247_taught_lean_verification_snippets_that_noop/reports/01_taught-lean-snippets-noop.md`
