# Research Report: Task #377

**Task**: 377 - Add shellcheck gate to agent-system
**Started**: 2026-10-09T00:00:00Z
**Completed**: 2026-10-09T00:00:00Z
**Effort**: medium (one new lint script + one gate wiring + ~196 mechanical/judgment fixes across 82 files)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/verify-deploy.sh`, `agent-system/extensions/core/scripts/tests/run-all.sh`, `agent-system/extensions/core/scripts/lint/*.sh` and their `tests/test-lint-*.sh` fixtures
- Live tool run: `shellcheck -S warning` (v0.11.0, resolved via `/home/benjamin/.nix-profile/bin/shellcheck`) against all 359 `*.sh` files under `agent-system/extensions/`
- Reference precedent: `~/Projects/Logos/Verification/scripts/lint-shell.sh` (the exit-70 "unresolvable binary" convention named in the task description)
**Artifacts**: this report (`specs/377_add_shellcheck_gate_to_agent_system/reports/01_shellcheck_gate.md`)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- No shellcheck gate exists anywhere in the agent system today; re-running `shellcheck -S warning`
  against the source store (`agent-system/extensions/`, all 359 `*.sh` files, all extensions —
  not just core) now gives **196 findings across 82 files**, closely reproducing the dispatch's
  2026-10-09 deployed-tree measurement (~180/~85) including exact matches on every specifically
  named finding (both SC2066 single-pass loops, both session_id SC2154 sites, both SC2319 sites).
  The small count/file delta is deployed-vs-source-store drift, not a measurement error.
- The codebase already has a mature, repeatable pattern for exactly this kind of gate: a
  standalone `lint/lint-*.sh` script (source-store-only, `[SKIP]` on a deploy consumer), wired as
  one more numbered gate in `verify-deploy.sh` (currently gates 1-21, Gate 12
  `lint-state-writer-boundary.sh` is the closest analog), with its own both-polarity
  `tests/test-lint-*.sh` fixture suite picked up automatically by `run-all.sh`'s `test-*.sh`
  discovery. The new shellcheck gate should follow this pattern exactly rather than inventing a
  new one.
- Recommended approach: a new `lint/lint-shellcheck.sh` that resolves `shellcheck` via `PATH`
  (no nix devShell needed here — unlike Logos/Verification, this repo has no `flake.nix` lint
  devShell to enter), runs `shellcheck -x -S warning` over `git ls-files -z -- 'agent-system/extensions/*.sh'`
  (tracked files only, scoped under the directory the task names), and exits a distinct non-zero
  code (adopt the sibling repo's `70`) with a named stderr message when the binary cannot be
  resolved — never a silent skip, matching the task's explicit precedent citation.
- Findings decompose into a fixable tail (SC2066 single-pass loops: 2; SC2155 masked exit codes:
  15; SC2164 cd-without-`|| exit`: 31; SC2154 referenced-not-assigned: 10, including the 2
  `session_id` closed-over-global sites; SC2319: 2; SC2088/SC2043/SC2010/SC1090/SC2207/SC2206/
  SC2063/SC2125/SC2053: 25 combined) and one dominant, judgment-heavy category: **SC2034 unused
  variable, 108 occurrences** — more than half of all findings, spread thin across many files,
  requiring a per-site call between "genuinely dead, delete it" and "closed-over global/exported
  for a child process, inline-disable with a one-line reason" (the codebase already has a
  documented precedent for the latter in `skill-base.sh`'s `SKILL_HOOK_LAST_*` comment).

## Context & Scope

Researched: (1) whether a shellcheck gate or equivalent already exists anywhere in the agent
system — it does not; (2) the current, re-measured finding set against the source store (the
task explicitly says "re-measure in the source store at research time; the deployed count is a
guide, not the target list"); (3) the existing lint-gate architecture in
`verify-deploy.sh`/`run-all.sh` that a new gate must slot into; (4) the external precedent the
task cites (`Logos/Verification/scripts/lint-shell.sh`) for the "unresolvable binary = named
non-zero failure" requirement.

Out of scope (per the dispatch): consumer repos' own lint sets (Logos/Verification can drop
`.claude/` from its lint scope once this lands, but that change is filed there, not here).

## Findings

### Codebase Patterns

**No existing shellcheck wiring.** `grep -rn shellcheck` across `agent-system/extensions/`
returns only inline `# shellcheck disable=SCxxxx` / `# shellcheck source=...` directives already
present in ~40 files (the codebase already practices deliberate, reasoned inline disables — no
blanket file-level disables found) and zero lint-gate or CI wiring. `run-all.sh`'s own header
confirms no lint runner currently shells out to `shellcheck`.

**The lint-gate pattern (precedent to copy, not invent).** `agent-system/extensions/core/scripts/lint/`
holds 12 standalone lint scripts today (`lint-state-writer-boundary.sh`,
`lint-hook-registration-paths.sh`, `lint-routing-wiring.sh`, etc.). Each follows the same shape,
best exemplified by Gate 12 (`lint-state-writer-boundary.sh`) and Gate 21
(`lint-hook-registration-paths.sh`) in `verify-deploy.sh` (lines ~719-744 and ~1132-1153):

```bash
if gate_selected 12; then
say "12. State-writer boundary lint (lint-state-writer-boundary.sh --verbose)"
CURRENT_GATE="gate12"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- ... does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh" ]; then
  fail "lint-state-writer-boundary.sh not found in source store"
else
  state_writer_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash ".../lint-state-writer-boundary.sh" --verbose 2>&1)
  state_writer_lint_status=$?
  if [ "$state_writer_lint_status" -eq 0 ]; then
    pass "..."
  else
    fail "..." "re-run for detail: ..." ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r line; do FINDINGS_LIST+=("FINDING gate12 ${line#*VIOLATION\] }"); done < <(printf '%s\n' "$output" | grep -F '[VIOLATION]')
    fi
  fi
fi
say ""
fi
```

Key properties of this pattern that the new gate must preserve:
- **Source-store-only, loud `[SKIP]` elsewhere**: every lint gate checks
  `[ ! -d "$TARGET/agent-system/extensions" ]` and prints an explicit `[SKIP]` line (never a
  silent pass) when invoked against a deployed `.claude/` consumer tree rather than the source
  store — because the lint is about hygiene of *authored* scripts, which only exist pre-merge.
  This directly matches the task's scope line ("lint every `*.sh` under
  `agent-system/extensions/`").
- **Numbered gate, validated range**: `verify-deploy.sh` validates `--only-gate` tokens against
  a hardcoded `1-21` range at two call sites (`verify-deploy.sh:119,125`, the error text itself
  says "must be a number 1-21" / "out of range (must be 1-21)"). The next gate is **22**, and
  both literal range strings must be bumped to `1-22`.
- **Own fixture test, discovered by `run-all.sh` automatically**: every `lint-*.sh` has a sibling
  `tests/test-lint-*.sh` (e.g. `test-lint-state-writer-boundary.sh`) that is a **test of the
  lint**, not of the target tree — it writes synthetic fixtures to a `mktemp -d` workdir and
  asserts both polarities (a clean fixture passes; a seeded violation fails), following a
  documented resolve-the-lint-script-path helper that works from both the source-store and
  deployed invocation depths. `run-all.sh` discovers `tests/test-*.sh` globally across every
  extension directory, so no separate wiring step is needed to pick the new test up — this is
  exactly the mechanism the task's acceptance criterion ("a seeded SC2155 in a fixture fails it")
  is asking for.
- **No separate context/standards doc per lint**: none of the 12 existing `lint-*.sh` scripts has
  a companion `context/standards/*.md` file; each is self-documented in its own file header
  (`lint-state-writer-boundary.sh`'s header is an unusually thorough example, including an
  explicit "KNOWN LIMITATION" section). The new gate should follow this convention rather than
  add a new context file.

**Unresolvable-binary precedent.** `~/Projects/Logos/Verification/scripts/lint-shell.sh` is the
exact source the task description cites ("precedent: Logos/Verification's
`scripts/lint-shell.sh` exit 70"). Reading it confirms the convention precisely: `EXIT_UNRESOLVED=70`,
a named stderr message ("`shellcheck` is not resolvable ... No substitute check was run."),
`bash -n` is explicitly called out as *not* an acceptable substitute, and the binary is invoked
as `shellcheck -x -S warning "${files[@]}"` over `git ls-files -z '*.sh'`. That repo gates
`shellcheck` behind a nix devShell (`nix develop .#lint`) because its contributors don't all have
it on `PATH`; this repo already has `shellcheck` resolvable directly via `/home/benjamin/.nix-profile/bin/shellcheck`
(and `nvim`/`jq`/etc. are already invoked directly by `verify-deploy.sh` elsewhere via
`command -v`), so the new `lint-shellcheck.sh` does not need a devShell re-entry branch — only
the `command -v shellcheck` check and the `EXIT_UNRESOLVED` convention need to be adopted, not
the nix-develop wrapping.

### Live Measurement (source store, 2026-10-09, shellcheck 0.11.0)

```
shellcheck -S warning -f gcc $(find agent-system/extensions -name '*.sh' -type f)
# exit 1, 196 findings across 82 of 359 files
```

Running with `-x` (follow `source`/`.` statements — the flag the Logos/Verification precedent
uses) produces byte-identical counts on this tree today; no finding depends on cross-file
resolution currently, but `-x` costs nothing and should be adopted anyway for parity with the
cited precedent and to stay correct if a future source-chain-dependent finding appears.

By code (warning+ severity):

| Code | Count | Nature | Fix shape |
|------|-------|--------|-----------|
| SC2034 | 108 | "appears unused" | Per-site judgment: delete dead var, or `# shellcheck disable=SC2034` + one-line reason when it's a closed-over global/exported-for-child-process (precedent: `skill-base.sh:195`'s `SKILL_HOOK_LAST_*` comment) |
| SC2164 | 31 | `cd` without `|| exit`/`|| return` | Append `|| exit 1` (top-level/script context) or `|| return 1` (inside a function, e.g. a per-worker subshell in a concurrency test) |
| SC2155 | 15 | `local x=$(cmd)` masks `cmd`'s exit code | Split into `local x; x=$(cmd)` |
| SC2154 | 10 | var referenced but never assigned in this file | 2 are the task-named `session_id` sites (`lib/territory-contention-lib.sh:237`, `lib/redeploy-checkpoint-lib.sh:216`) — confirmed closed-over globals the caller script is expected to set before sourcing the lib, same pattern as the SC2034 exported-global case; inline-disable with reason. Remaining 8 (`triage_ndjson`, `admit_ndjson`, `canonical_force_phases_json`, `new_cycle_count`, `post_deploy_reconcile_json`, `dry_run`, `cycle_count`, `_p`) need the same per-site "caller-provided global vs. genuine bug" triage |
| SC2088 | 6 | quoted `~` doesn't expand | Replace with `$HOME` or unquote |
| SC2043 | 5 | loop over a value with only one possibility | Case-by-case; may be intentional (single-element list for symmetry) → disable+reason, or dead loop → simplify |
| SC2010 | 4 | `ls \| grep` | Replace with a glob or `for f in dir/*pattern*` |
| SC1090 | 4 | non-constant source, can't follow | Already the codebase's dominant existing disable category (~40 pre-existing `SC1090` disables); these 4 are new/missed sites needing the same disable |
| SC2207 | 3 | unquoted command substitution into array | `mapfile`/`read -a` instead, or disable+reason if intentional word-splitting (precedent: `roadmap-integration.sh:324`'s existing SC2206 reason comment) |
| SC2319 | 2 | `$?` refers to a condition (`if`/`[[`), not the preceding command | `test-orchestrate-cycle-plan.sh:4040,4042` — assign the real command's exit code to a variable before the conditional |
| SC2206 | 2 | unquoted array assignment | Quote, or disable+reason (same precedent as SC2207) |
| SC2066 | 2 | double-quoted loop var makes a `for` single-pass | The 2 named-in-dispatch real defects: `lean/scripts/tests/test-lean-mcp-preflight-check.sh:102` and `core/scripts/tests/test-resume-scan-nonconformance.sh:140` — unquote or restructure to actually iterate |
| SC2063 | 2 | grep pattern looks like a regex but is used as a glob (or vice versa) | Case-by-case |
| SC2125 | 1 | glob assigned to a variable without quoting intent | Case-by-case |
| SC2053 | 1 | unquoted RHS of `[[ = ]]` triggers glob matching | Quote unless the glob is intentional |

Heaviest files (candidates for the deepest per-site review pass): `core/scripts/test-state-write-concurrency.sh`
(21, nearly all SC2164 `cd` sites inside per-worker subshells plus a few SC2010), `core/scripts/test-state-write-large-payload.sh`
(13), `core/scripts/lib/phase-heading-patterns.sh` (10), `core/scripts/uninstall-extension.sh` (6),
`core/scripts/install-extension.sh` (6).

## Recommendations

1. **New lint script**: `agent-system/extensions/core/scripts/lint/lint-shellcheck.sh`.
   - Resolve the file set via `git ls-files -z -- 'agent-system/extensions/*.sh'` from
     `REPO_ROOT` (tracked files only — matches the Logos/Verification precedent and avoids
     linting stray untracked scratch scripts a contributor might have sitting in the tree).
   - Invoke `shellcheck -x -S warning "${files[@]}"`.
   - `command -v shellcheck` check first; on failure, print a named message and `exit 70`
     (adopting the cited precedent's exact convention) — never fall back to `bash -n` or any
     other substitute, and never exit 0.
   - `[SKIP]` posture when `$TARGET/agent-system/extensions` doesn't exist (deploy-consumer
     invocation), matching every sibling lint gate.
   - A `--verbose`/plain findings-emission convention consistent enough with Gate 12/21's
     `[VIOLATION]`-line scraping that `verify-deploy.sh` can extract one `FINDING gate22 ...` per
     shellcheck finding line when `--findings` is requested; shellcheck's own `gcc`-format output
     (`file:line:col: severity: message [SCxxxx]`) is already machine-parseable per-line, so this
     is a formatting/prefixing concern, not a new detection mechanism.
2. **Wire as Gate 22** in `verify-deploy.sh`, inserted immediately before the final
   `if [ "$FAILURES" -eq 0 ]` block (i.e. right after today's Gate 21 block), modeled line-for-line
   on Gate 12/21. Bump both `--only-gate` range-validation literals (`verify-deploy.sh:119,125`,
   "must be a number 1-21" / "out of range (must be 1-21)") to `1-22`.
3. **Fixture test**: `agent-system/extensions/core/scripts/tests/test-lint-shellcheck.sh`,
   structurally modeled on `test-lint-state-writer-boundary.sh` (mktemp workdir, resolve-candidate
   helper for source-store-vs-deployed invocation depth, both-polarity assertions): a clean
   fixture script passes; a fixture seeded with `local x=$(false)` (SC2155) fails. This satisfies
   the acceptance criterion verbatim and is auto-discovered by `run-all.sh` with no further
   wiring.
4. **Fix pass ordering** for the ~196 current findings: do the small, mechanical, unambiguous
   categories first (SC2066 — 2 real single-pass-loop bugs; SC2155 — 15; SC2164 — 31; SC2088/
   SC2010/SC2206/SC2207/SC2063/SC2125/SC2053 — 19 combined; SC2319 — 2), then the per-site
   judgment categories (SC2154 — 10, SC1090 — 4), then the large, thin-spread SC2034 pass (108,
   across most of the 82 flagged files) last, since it is the most time-consuming and the one
   most likely to surface a genuine dead-code deletion opportunity alongside the expected
   closed-over-global disables.
5. **Disable discipline**: every deliberate disable gets an inline `# shellcheck disable=SCxxxx`
   with a one-line reason on the same or preceding line — the codebase already does this
   consistently (e.g. `lib/territory-contention-lib.sh:221,225` for SC2254,
   `roadmap-integration.sh:324` for SC2206, `skill-base.sh:195` for SC2034), so the new fixes
   should match house style rather than introduce a new comment convention. No file- or
   repo-level blanket disable (`.shellcheckrc` at root disabling a whole code class) should be
   added — the task explicitly forbids this.
6. **Re-verify before closing**: after the fix pass, re-run the exact measurement command above
   against the source store and confirm `shellcheck -x -S warning` over the full tracked `*.sh`
   set exits 0, then confirm Gate 22 (and the fixture test) both pass through `run-all.sh`/
   `verify-deploy.sh`.

## Decisions

- Use `verify-deploy.sh`'s existing numbered-gate mechanism (new Gate 22) rather than folding the
  shellcheck run into `run-all.sh`'s suite-discovery loop directly — `run-all.sh` discovers
  `test-*.sh` *suites*, and a standalone `lint-*.sh` + fixture-test pair is the established shape
  for a repo-wide static-analysis gate (12 precedents already follow it; zero precedents fold a
  non-test lint directly into `run-all.sh`'s own body).
- Scope the lint to `git ls-files` (tracked files) rather than a raw `find`, matching the cited
  Logos/Verification precedent and avoiding false failures on a contributor's untracked scratch
  scripts.
- Adopt `-x` (follow source) even though it changes nothing on today's tree, for precedent parity
  and future-proofing.
- No new `context/standards/*.md` doc for this lint — follow the existing convention of
  self-documenting the lint script's own header comment (every sibling lint gate does this; none
  has a separate standards file).

## Risks & Mitigations

- **SC2034's 108 findings are the dominant risk to scope/time.** Many are likely legitimate
  closed-over-globals or script-boilerplate (`SCRIPT_DIR` assigned but only used inside a
  function defined later, which shellcheck sometimes still flags depending on control flow) and
  will resolve to a quick disable+reason; a smaller number are probably genuinely dead and should
  simply be deleted. Mitigation: triage by file during implementation rather than by code —
  `test-state-write-concurrency.sh`/`test-state-write-large-payload.sh`/`phase-heading-patterns.sh`
  concentrate the bulk of the non-SC2034 findings too, so a file-at-a-time pass is efficient.
- **A seeded SC2164 fix inside a backgrounded worker subshell (`test-state-write-concurrency.sh`)
  could change failure semantics** if `|| exit` is used where `|| return` (or a worker-local
  failure flag) was intended, silently killing a concurrency-test harness early. Mitigation: use
  `|| return 1` inside any function/subshell context and verify `run-all.sh`'s own result for that
  suite is unchanged after the fix (PASS count and timing), not just that shellcheck is now quiet.
- **Shellcheck version drift**: counts here are measured against 0.11.0; a different shellcheck
  version resolved on `PATH` elsewhere (e.g. a CI runner, or a future nix-profile upgrade) could
  report a different finding set at the same `-S warning` level. This is inherent to any
  binary-resolved (non-pinned) lint and matches the Logos/Verification precedent's own exposure;
  no action needed beyond noting it, since the task's acceptance criterion is "passes on the
  source store" at research/implementation time, not pinned-forever.

## Context Extension Recommendations

- **Topic**: shellcheck gate conventions.
- **Gap**: none significant — the existing lint-gate pattern (self-documented per-script headers,
  no separate standards file) already covers everything a future reader would need, and this task
  is meta/mechanical rather than domain knowledge that benefits from a new context file.
- **Recommendation**: none; rely on the new `lint-shellcheck.sh`'s own header comment, matching
  sibling lint scripts.

## Appendix

Commands/queries used:
- `jq -r '.extensions | to_entries[] | "\(.key): \(.value.source_dir)"' .claude-extensions.json`
  (confirmed source-store resolution per `source-store-deploy-boundary.md`)
- `find agent-system/extensions -name '*.sh' -type f | wc -l` → 359
- `shellcheck -S warning -f gcc $(…) ` and `shellcheck -x -S warning -f gcc $(…)` → 196 findings,
  82 files, both flag variants identical on this tree
- `grep -oP '\[SC\d+\]' … | sort | uniq -c | sort -rn` (per-code breakdown table above)
- `grep -oP '^[^:]+\.sh' … | sort | uniq -c | sort -rn` (per-file breakdown, heaviest files above)
- Read `agent-system/extensions/core/scripts/verify-deploy.sh` (Gate 12 lines ~719-744, Gate 21
  lines ~1132-1153 and file tail ~1155-1215, `--only-gate` validation lines 119/125)
- Read `agent-system/extensions/core/scripts/tests/run-all.sh` header (suite-discovery model)
- Read `agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh` (fixture
  test structural model)
- Read `~/Projects/Logos/Verification/scripts/lint-shell.sh` in full (exit-70 precedent, `-x -S
  warning`, `git ls-files` file-set resolution)
- `ls agent-system/extensions/core/scripts/lint/` (12 existing lint scripts) and
  `agent-system/extensions/core/scripts/tests/ | grep -i lint` (12 matching fixture tests)
