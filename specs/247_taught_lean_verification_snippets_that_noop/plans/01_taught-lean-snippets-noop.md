# Implementation Plan: Task #247

- **Task**: 247 - Taught Lean verification snippets that no-op
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: 221, 173 (both landed; re-derive every line number against the current tree)
- **Research Inputs**: specs/247_taught_lean_verification_snippets_that_noop/reports/01_taught-lean-snippets-noop.md
- **Artifacts**: plans/01_taught-lean-snippets-noop.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two taught-snippet defects in `agent-system/extensions/lean/` (the source store -- never
`.claude/**`) are fixed together because they share edit targets. Half 1 corrects every
`lake-build-guard.sh` invocation whose first post-`--` token is a module name instead of a lake
subcommand (exit 77, no build). Half 2 replaces the hardcoded `Theories/` scan root with a single
resolver script, `lean-src-roots.sh`, that derives source roots from the consuming repo's
`lakefile.toml` and fails loudly when the resolved roots are missing or hold zero `.lean`
files. `lean-sorry-census.sh` separately stops exiting 0 on an empty or missing target. The
last phase checks both halves in real consuming repos and redeploys.

### Research Integration

- Half 1: three confirmed-broken sites (re-derived): `rules/lean4.md:48`,
  `agents/lean-implementation-hard-agent.md:237`, `skills/skill-lake-repair/SKILL.md:79`.
  Placeholder trio: `rules/lean4.md:71,76` and `context/project/lean4/operations/long-builds.md:75`.
  `comparator-integration.md`'s `-- env ...` is correct (`env` is on the allowlist).
- Half 2: `lean-sorry-census.sh` lines ~72-95 confirmed to print a stderr warning, then
  `sorry_count: 0` / exit 0, when its target is missing or empty. Executable `Theories/` sites
  sit in both `lean-implementation*-agent.md` files (census, vacuous-def grep, axiom grep,
  plan-compliance grep, comparator-preflight discovery), in both `skill-lean-implementation*`
  SKILL.md Stage 8 `git-commit-scoped.sh` path lists, in the census usage comment, and in
  `challenge-snapshot.md` prose.
- Both real consumers (BimodalLogic, cslib) use `lakefile.toml`. Python 3.13 is available, so
  the stdlib `tomllib` works. BimodalLogic's project-local `scripts/lake_targets.py` shows the
  default rules to apply (`srcDir` default `"."`, `roots` default `[name]`) but cannot be reused
  from the source store.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap consulted (no roadmap_path in dispatch).

## Decisions

- **D1 (Half 1 placeholder)**: Rewrite the placeholder as `-- <lake-subcommand> [args]` in the
  canonical block of `long-builds.md` and in both `rules/lean4.md` occurrences. Put a concrete
  `# e.g. -- build Module.Name` right beside it. Reason: a reader who expands the placeholder
  then cannot reproduce the defect, and the block stays generic, because callers also use
  `env`, not only `build`.
- **D2 (Half 2 helper shape)**: Use a NEW script, `agent-system/extensions/lean/scripts/lean-src-roots.sh`,
  not a function inside `lean-sorry-census.sh` and not a bare `$LEAN_SRC_ROOTS` variable.
  Reason: the consumers include raw greps, plan-compliance/comparator discovery, and
  `git-commit-scoped.sh` staging. None of these are census calls, so a census-internal function
  would force them all through the census. A bare variable would need something to compute it,
  and that something is this script. Having one script means there is exactly one place that
  can be wrong.
- **D3 (source of truth)**: `lakefile.toml` `[[lean_lib]]` entries are authoritative. By default
  the script uses ALL `lean_lib` entries, so it covers library and test sources (BimodalLogic:
  `FormalSystem/`, `Tests/BimodalTest/`, and so on). For each root it emits `srcDir/Root/` (a
  directory) and `srcDir/Root.lean` (a file), keeping whichever exist. `globs` get a best-effort
  mapping (`Foo.+`/`Foo.*` -> `Foo/`), with any unsupported glob form documented. An optional
  `--default-targets` flag limits output to `defaultTargets`.
- **D4 (fallback)**: `LEAN_SRC_ROOTS` (whitespace-separated paths) is read ONLY when no
  `lakefile.toml` exists, for example in repos with only `lakefile.lean`. If `lakefile.toml`
  exists, the variable is ignored and a stderr notice says so. This keeps one convention, not two
  competing ones.
- **D5 (loud failure lives in the resolver AND the census)**: The resolver exits non-zero,
  naming the root(s) it tried, when any of these hold: no lakefile.toml and no env value; an
  unparseable lakefile; no lean_lib entries; zero existing roots; zero `.lean` files across the
  roots. Independently, `lean-sorry-census.sh` exits non-zero (a new documented code, e.g. 66)
  when a target does not exist or when zero `.lean` files are collected. A missing target
  becomes fatal instead of a warning. This covers anyone who calls the census directly.
- **D6 (exit-77 message)**: `lake-build-guard.sh` is not edited here. The suggestion to name
  `-- build Module.Name` in its exit-77 message is recorded in the implementation summary for
  the guard-owning work, and nothing more is done with it.
- **D7 (prose `Theories/` sites)**: These stay unchanged: `context-hygiene.md:34,69`,
  `anti-analysis.md:57`, `lean-research-hard-agent.md:135`, and
  `lean-implementation-hard-agent.md:117`. They are illustrative read-budget or phase-scope
  prose, not executable checks. The `"file": "Theories/Foo.lean"` sample JSON in
  `lean-implementation-hard-agent.md` (~line 313) becomes a neutral `"<src-root>/Foo.lean"`, so
  a sample output does not re-teach the literal.

## Goals & Non-Goals

**Goals**:
- No lean-extension file teaches a guard invocation that would exit 77 (checked exhaustively).
- No taught verification or commit snippet names a literal source root. All of them call
  `lean-src-roots.sh`.
- A missing or empty scan root is a non-zero exit that names the root, in both the resolver and
  the census.
- The fixes are live in a consuming repo's regenerated `.claude/**`.

**Non-Goals**:
- Editing `agent-system/extensions/core/scripts/lake-build-guard.sh`, its tests,
  `LAKE_SUBCOMMANDS`, or exit 77.
- Restating the build-verdict evidence hierarchy or the un-piped exit-code contract. Point at
  `long-builds.md`'s "Reading the build's verdict" anchor instead.
- Touching `scripts/tests/` fixtures that legitimately use `Theories/`.
- Full `lakefile.lean` parsing (the `LEAN_SRC_ROOTS` fallback covers it).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Making a missing census target fatal breaks existing census tests or callers relying on warn-and-skip | M | M | Run `test-lean-sorry-census.sh` before and after. Grep callers of the census across the extension, and adjust any caller that depended on skip behavior |
| `globs` forms in some lakefile not mappable | L | L | Document the supported forms; an unsupported glob falls back to root-based mapping and prints a stderr note, never a silent drop |
| Snippet rewrite uses a process substitution that swallows the resolver's non-zero exit | H | M | Taught shape MUST capture via `roots=$(bash .claude/scripts/lean-src-roots.sh) \|\| { echo ...; exit 1; }` then `mapfile -t`. Never `< <(...)` alone. Checked in Phase 4's verification |
| Planting a sorry in BimodalLogic leaves residue | M | L | Plant it in a NEW temp file under `FormalSystem/`, delete it immediately, and confirm `git -C ~/Projects/BimodalLogic status --porcelain` matches its pre-test state |
| Deploy into a consuming repo overwrites unrelated local state | M | L | Use `deploy-headless.sh` per its documented usage (read its header first); no `--wipe` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 2, 3 |
| 3 | 5 | 1, 4 |

Phases within the same wave can execute in parallel. Phase 1 and Phase 4 both edit
`lean-implementation-hard-agent.md` and `rules/lean4.md`-adjacent content. If they run in
parallel, the territory rule is that Phase 1 owns only the guard-invocation lines and Phase 4
owns only the `Theories/` lines. Running them serially (1 before 4) is the safe default.

### Phase 1: Half 1 -- fix guard invocation vectors [COMPLETED]

**Goal**: Every `lake-build-guard.sh` invocation in the lean extension has an allowlisted lake
subcommand as its first post-`--` token.

**Tasks**:
- [x] Re-derive sites: `grep -rn "lake-build-guard.sh\|build --timeout" agent-system/extensions/lean/` *(completed)*
- [x] `rules/lean4.md` (~48): `-- Module.Name` -> `-- build Module.Name` *(completed)*
- [x] `agents/lean-implementation-hard-agent.md` (~237): `-- ModuleName 2>&1` -> `-- build ModuleName 2>&1` *(completed)*
- [x] `skills/skill-lake-repair/SKILL.md` (~79): `-- "$module"` -> `-- build "$module"` *(completed)*
- [x] Placeholders per D1: `long-builds.md` (~75) canonical block and `rules/lean4.md` (~71, ~76) *(completed: rewritten as `-- <lake-subcommand> [args]` with a `# e.g. -- build Module.Name` comment)*
- [x] Exhaustive audit: extract every post-`--` first token from every guard invocation in the
      extension and check each against `LAKE_SUBCOMMANDS` (read it from the guard, don't copy
      it). Placeholders must read `<lake-subcommand>`. Keep the audit as a one-off command
      recorded in the summary, not a new deliverable file *(completed: grep -rn "lake-build-guard.sh.*-- " agent-system/extensions/lean/ shows only `env`, `build`, and `<lake-subcommand>` as first post-`--` tokens, all allowlisted or placeholder-conformant)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: 3 concrete broken sites plus 3 placeholder occurrences in 2 files (per
research). Confirm by the audit grep; fix any extra site it surfaces.

**Files to modify**:
- `agent-system/extensions/lean/rules/lean4.md` - broken vector plus placeholder wording
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - broken vector
- `agent-system/extensions/lean/skills/skill-lake-repair/SKILL.md` - broken vector
- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` - placeholder wording

**Verification**:
- The audit reports zero invocations whose first post-`--` token is outside the allowlist
  (placeholders count only when they read `<lake-subcommand>`)
- `git diff` shows no change under `agent-system/extensions/core/`

---

### Phase 2: Half 2 -- `lean-src-roots.sh` resolver with tests [COMPLETED]

**Goal**: One resolver that emits the consuming repo's Lean source roots and fails loudly.

**Tasks**:
- [x] Create `agent-system/extensions/lean/scripts/lean-src-roots.sh`: bash wrapper plus an
      embedded `python3` `tomllib` reader. Resolve the repo root (`git rev-parse --show-toplevel`,
      or CWD). Apply D3/D4 rules. Output one existing path per line, relative to the repo root *(completed)*
- [x] Loud-failure behavior per D5, with distinct documented exit codes and stderr messages that
      name the lakefile path and every root tried *(completed: exit 64 usage, 65 no lakefile/no env, 66 unparseable/no python3, 67 zero lean_lib entries, 68 zero existing roots, 69 zero .lean files)*
- [x] Header comment: purpose, precedence (lakefile.toml > LEAN_SRC_ROOTS), exit codes, and the
      taught consumption shape (capture with `||` guard, then `mapfile -t`) *(completed)*
- [x] Create `scripts/tests/test-lean-src-roots.sh`, following the `test-lean-sorry-census.sh`
      conventions. Fixtures: BimodalLogic-shaped lakefile (`srcDir = "Tests"`, several libs);
      cslib-shaped (defaults only); `defaultTargets` flag; missing root dir -> non-zero exit
      naming it; roots that exist but hold zero `.lean` files -> non-zero; no lakefile plus
      `LEAN_SRC_ROOTS` set -> used; no lakefile and no env -> non-zero; lakefile present plus
      env -> env ignored with a notice; malformed TOML -> non-zero. Add a mutation check: at
      least one fixture must fail if the empty-file check is removed *(completed: 10 fixtures A-I plus mutation-check reasoning documented on Fixture G, all passing)*
- [x] Register both files in `agent-system/extensions/lean/manifest.json` `provides.scripts` *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-src-roots.sh` - new
- `agent-system/extensions/lean/scripts/tests/test-lean-src-roots.sh` - new
- `agent-system/extensions/lean/manifest.json` - register scripts

**Verification**:
- `bash agent-system/extensions/lean/scripts/tests/test-lean-src-roots.sh` exits 0
- `(cd ~/Projects/BimodalLogic && bash <src>/lean-src-roots.sh)` lists `FormalSystem` (and
  `FormalSystem.lean`) plus the `Tests/...` roots; the same in cslib lists `Cslib`
- `jq . manifest.json` parses

---

### Phase 3: Half 2(c) -- `lean-sorry-census.sh` fails loudly on missing or empty targets [COMPLETED]

**Goal**: The census can no longer print `sorry_count: 0` when it scanned nothing.

**Tasks**:
- [x] Run `scripts/tests/test-lean-sorry-census.sh` to get a baseline *(completed: 14/14 passing before changes)*
- [x] Nonexistent target: error naming the target, then a non-zero exit (not warn-and-skip) *(completed: exit 65)*
- [x] Zero `.lean` files collected: error naming all targets, then a non-zero exit (replaces the
      exit-0 block at ~lines 92-95). Document the new exit code in the header *(completed: exit 66)*
- [x] Update the usage comment (~line 26) to the resolver form, e.g.
      `bash .claude/scripts/lean-sorry-census.sh $(bash .claude/scripts/lean-src-roots.sh) --cross-check`
      in its guarded shape, with no literal `Theories/` *(completed: guarded capture + mapfile shape, no literal root)*
- [x] Add fixtures to `test-lean-sorry-census.sh`: a nonexistent dir -> non-zero exit and stderr
      names it; an empty dir (no `.lean` files) -> non-zero; a clean dir with real `.lean`
      files and no sorry -> exit 0 `sorry_count: 0`, so "scanned and clean" stays distinct
      from "scanned nothing" *(completed: Fixtures J, K, L; 17/17 passing, existing A-I unchanged)*
- [x] Grep the extension for other census callers; adjust any that depended on skip behavior *(completed: only prose references and the sibling-suite regression check in test-lean-comparator-run.sh, which calls the TEST SUITE not the census directly with a possibly-missing target -- no caller depended on the old skip behavior)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-sorry-census.sh` - loud failure plus usage text
- `agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` - new fixtures (existing
  fixtures unchanged)

**Verification**:
- The census test suite exits 0, including the new fixtures
- `bash lean-sorry-census.sh /nonexistent; echo $?` gives non-zero, and stderr names `/nonexistent`

---

### Phase 4: Half 2(a)(b)(d) -- route every taught snippet through the resolver [COMPLETED]

**Goal**: No taught snippet names a literal root. All of them get roots from `lean-src-roots.sh`.

**Tasks**:
- [x] Re-derive sites: `grep -rn "Theories/" agent-system/extensions/lean/ | grep -v scripts/tests/` *(completed)*
- [x] `agents/lean-implementation-agent.md`: add one "resolve source roots" step at the top of
      final verification, using the guarded capture from the Phase 2 header. Point the census,
      vacuous-def grep, axiom grep, plan-compliance grep and echo text, replacement-target grep,
      and both comparator-preflight blocks at `"${lean_roots[@]}"`. Reword echo and reason text
      to "the resolved source roots" *(completed)*
- [x] `agents/lean-implementation-hard-agent.md`: the same for the census, vacuous-def grep,
      axiom grep, the plan-compliance prose (~421), and both comparator-preflight blocks. Apply
      the neutral sample path per D7 *(completed: sorry_inventory sample "file" now "<src-root>/Foo.lean")*
- [x] `skills/skill-lean-implementation/SKILL.md` and `skills/skill-lean-implementation-hard/SKILL.md`
      Stage 8: replace `-- "Theories/"` with the resolved roots. On resolver failure the commit
      step must abort loudly, never commit without the sources *(completed: guarded resolve step added immediately before each commit)*
- [x] `context/project/lean4/domain/challenge-snapshot.md:20`: describe the check as a grep over
      the roots resolved by `lean-src-roots.sh` *(completed)*
- [x] Leave the D7 prose sites alone, and record the decision in the summary *(completed: verified unchanged by final grep)*
- [x] Do not restate the exit-code or build-verdict contract. Any build-related wording points
      at `long-builds.md`'s "Reading the build's verdict" *(completed: no build-verdict wording touched)*

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: interface

**Scope Hypothesis**: about 20 executable `Theories/` occurrences across 6 files (per research
inventory). Confirm by the grep. The final grep must show only D7 prose sites and
`scripts/tests/` fixtures.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-agent.md`
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md`
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md`
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md`

**Verification**:
- `grep -rn "Theories/" agent-system/extensions/lean/ | grep -v scripts/tests/` lists only the
  D7 prose sites
- No taught snippet consumes the resolver through a bare `< <(...)` that drops its exit code
- Extract the rewritten final-verification snippet block and run it under `bash -n`

---

### Phase 5: End-to-end verification in consuming repos and redeploy [NOT STARTED]

**Goal**: Show acceptance criteria 1-5 by actually running things.

**Tasks**:
- [ ] Acceptance 1: re-run the Phase 1 exhaustive guard-vector audit over the final tree
- [ ] Acceptance 3: in a scratch dir (scratchpad) with no lakefile and no `FormalSystem/`, run the
      resolver and the census against a nonexistent root and an empty root. Record the non-zero
      exits and the stderr text that names the root
- [ ] Acceptance 4: in `~/Projects/BimodalLogic`, note `git status --porcelain`. Run the
      rewritten snippets unmodified (resolver + census + axiom grep) and confirm they scan
      `FormalSystem/` and `Tests/`. Create a temp file `FormalSystem/ZzPlantedSorry.lean`
      containing `theorem zz_planted : True := by sorry`, re-run, and confirm the census reports
      it. Delete the file and confirm `git status` matches the pre-test state
- [ ] Run all lean extension test suites touched (`test-lean-src-roots.sh`,
      `test-lean-sorry-census.sh`, `test-lean-challenge-snapshot.sh`)
- [ ] Acceptance 5: read the `deploy-headless.sh` header, then redeploy into a consuming repo (for
      example `~/Projects/BimodalLogic`). Confirm that `.claude/scripts/lean-src-roots.sh`
      exists there, that `.claude/agents/lean-implementation-agent.md` has no `Theories/`, and
      that `.claude/rules/lean4.md` shows `-- build Module.Name`. Redeploy this repo's
      `.claude/` too if the deploy flow expects it
- [ ] Deliverable-rule check: `grep -rnE "task [0-9]+|tasks [0-9]+" ` over the changed files
      outside specs/ gives no new hits
- [ ] Record D6 (the exit-77 message suggestion) in the implementation summary

**Timing**: 1.25 hours

**Depends on**: 1, 4

**Verification Tier**: full

**Files to modify**:
- None in the source store (verification plus deploy only). Temp files are created and removed.

**Verification**:
- Every acceptance criterion has recorded command output in the summary
- BimodalLogic's working tree matches its pre-test state after the plant/remove step

## Testing & Validation

- [ ] `test-lean-src-roots.sh` passes (new), including the mutation-check fixture
- [ ] `test-lean-sorry-census.sh` passes, with new missing/empty fixtures and existing fixtures unchanged
- [ ] Exhaustive guard-vector audit clean
- [ ] `Theories/` grep leaves only D7 prose and test fixtures
- [ ] Nonexistent/empty root gives a non-zero exit naming the root (run, not asserted)
- [ ] Planted sorry in BimodalLogic detected by unmodified snippets, then removed
- [ ] Redeployed consumer `.claude/**` carries both halves

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/lean-src-roots.sh` (new)
- `agent-system/extensions/lean/scripts/tests/test-lean-src-roots.sh` (new)
- Edited: `rules/lean4.md`, `long-builds.md`, `skill-lake-repair/SKILL.md`, both
  `lean-implementation*-agent.md`, both `skill-lean-implementation*/SKILL.md`,
  `lean-sorry-census.sh`, `test-lean-sorry-census.sh`, `challenge-snapshot.md`, `manifest.json`
- `specs/247_taught_lean_verification_snippets_that_noop/summaries/01_taught-lean-snippets-noop-summary.md`

## Rollback/Contingency

All edits are confined to `agent-system/extensions/lean/`. Revert with
`git checkout -- agent-system/extensions/lean/` plus removal of the two new files, then
redeploy. If lakefile parsing proves fragile in Phase 2, keep the resolver's interface and
failure contract and narrow it to the `LEAN_SRC_ROOTS` fallback plus the default-rule-only
lakefile read (D4). Phase 4 does not depend on how parsing is implemented.
