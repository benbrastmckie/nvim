# Implementation Plan: Hook-registration path + fragment-coverage lint, wired as a verify-deploy gate

- **Task**: 365 - Lint forbidding CWD-relative paths and fragment-absent registrations in hook
  commands, wired as a verify-deploy gate
- **Status**: [COMPLETED]
- **Effort**: 6.5 hours
- **Dependencies**: Task 364 (upstream path-shape fix) — **completed**; its settled path shape and
  its D6 `settings.local.json` ruling are the inputs this lint encodes.
- **Research Inputs**: `specs/365_lint_cwd_relative_hook_path_registrations/reports/01_hook-registration-path-lint.md`
- **Artifacts**: plans/01_hook-registration-path-lint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  rules/source-store-deploy-boundary.md, context/standards/shell-script-testing.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Author one new source-store lint, `lint-hook-registration-paths.sh`, that gates four independent
defect classes in hook registrations — a relative invoked-script path (any directory, not only
`.claude/`), the same defective shape taught by a copy-paste registration template in source-store
markdown, a registration reachable only through install-once `root-files/settings.json` and by no
fragment surface, and a registration invoking a source-store script that does not exist — then wire
it into `verify-deploy.sh` as gate 21 with a both-polarity `mktemp -d` fixture suite. The corpus is
currently clean on all four checks (re-derived at plan-authoring time, see Scope Hypothesis lines),
so this task adds a guardrail against regression, not a migration; acceptance criterion 2 and 10
are satisfiable the moment the lint is written. Definition of done: all twelve acceptance criteria
from the dispatch hold, the full `verify-deploy.sh` battery passes with the new gate present, and
the whole task's work sits in the source store under `agent-system/extensions/core/` — never in
`.claude/`.

### Research Integration

The report settles every question the dispatch left conditional, and three of its findings change
the shape of the implementation rather than merely informing it:

1. **Accept condition is settled, not a choice.** Task 364 fixed the shape as
   `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh`. There is no second candidate to design around.
2. **`settings.local.json` is out of scope** by task 364's D6 ruling: a permission matcher matches
   literal command text presented by a tool call and is never itself resolved against a CWD, so it
   does not share the defect. The dispatch's "follows the upstream task's finding" conditional is
   thereby answered *no* — do not lint it, and say so in the script header so the question is not
   reopened.
3. **A key-anchored match is mandatory, not stylistic.** `core/root-files/settings.json` line 2's
   own `_comment` field quotes `"$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` in prose as a convention
   reminder. A lint that greps whole-file text for `.claude/hooks/` picks that `x.sh` up as a
   phantom registration. Every check must match on a `"command"` **key**, never on bare path text.
4. **MCP server `"command"` fields are a different shape.** `memory/settings-fragment.json` carries
   `"command": "npx"` under `mcpServers`, not under `hooks`. The lint must not match it.
5. **A documented identity divergence is accepted, not resolved.** `merge.lua`'s `hook_identity()`
   recognizes only `.claude/hooks/NAME.sh`; the dispatch's final revision requires this lint's
   fragment-coverage identity to be broader (any invoked script path). `merge.lua` is outside this
   task's `file_scope`, so the divergence is this task's explicit, reasoned boundary — recorded in
   the script header, not reconciled. Do **not** port `hook_identity`'s `hooks/`-anchored pattern.

### Prior Plan Reference

No prior plan. This is round 1 for task 365.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and `roadmap_flag` is absent, so no
roadmap-review/roadmap-update phases are added and `specs/ROADMAP.md` is not consulted or
modified.

## Goals & Non-Goals

**Goals**:

- One new lint script implementing four checks (path shape in settings surfaces; path shape in
  markdown registration templates; fragment coverage of root-files registrations; existence of
  every source-store-resolvable invoked script).
- Fail-**closed** behavior on a missing or broken shared library, with the fail-closed-vs-fail-open
  polarity contrast against the write-time hook convention stated explicitly in the script header.
- A both-polarity `mktemp -d` fixture suite covering every passing and failing shape the dispatch
  enumerates, including the explicit-`cd` direct-invocation passing case and the `scripts/`-relative
  (non-`.claude/`) failing case.
- A real numbered `verify-deploy.sh` gate (21) — registration in `manifest.json` alone does not
  satisfy criterion 3; two existing lints sit registered-but-unwired and this one must not join
  them.
- `manifest.json` registration of both new scripts at their alphabetically-correct positions.

**Non-Goals**:

- Repairing this repo's own deployed `.claude/settings.json` (whose line 21 still carries the live
  dead `bash scripts/claude-ready-signal.sh` registration). `.claude/**` is a disposable deploy
  artifact and never the correct edit target; the install-once staleness that strands it is a
  separate follow-up the research report already recorded.
- Broadening `merge.lua`'s `hook_identity()` to match this lint's wider identity notion.
- Linting `root-files/settings.local.json` permission matchers (task 364 D6).
- Rewriting `neovim-integration.md` line 34's `~/`-prefixed command away from the tilde form — see
  Decisions, which accepts `~/` as a third valid anchor instead.
- Committing any on-disk fixture files; every fixture is built and torn down inside `mktemp -d`.

## Decisions

Recorded here because each is a judgment call the implementation must not silently re-guess:

- **D1 — `~/` is an accepted third anchor.** The accept condition for an invoked script path is:
  `/`-absolute, OR `"$CLAUDE_PROJECT_DIR"`-prefixed, OR `~/`-prefixed. The report's open question
  is resolved in favor of accepting `~/`: it is demonstrably cwd-independent (it resolves through
  `$HOME`, not the session's drifted shell cwd), and it is already in deliberate, correct use at
  `nvim/context/project/neovim/guides/neovim-integration.md` line 34 for a real script at
  `~/.config/nvim/scripts/claude-ready-signal.sh` that is intentionally outside `.claude/`. Flagging
  it would be a false positive on a correct line, and rewriting that line is outside this task's
  `file_scope`. The script header must state this as a deliberate third anchor with the
  cwd-independence rationale, so a later reader does not "tighten" it back out.
- **D2 — a `~/`-anchored path is exempt from the existence check too.** It names a user-supplied,
  externally-provided script, which the dispatch explicitly instructs must not be failed for being
  absent from this repo. Scope the existence check to source-store-resolvable paths only (a
  `"$CLAUDE_PROJECT_DIR"`-anchored or `.claude/`-relative `hooks/NAME.sh` or `scripts/NAME.sh`).
- **D3 — `.sh` files are never scanned.** The lint's scan surface is settings JSON files plus
  source-store markdown. This is what makes criterion 7's explicit-`cd` case
  (`test-please-grant.sh` line 222: `( cd "$repo" && … | bash .claude/hooks/please-grant.sh )`)
  pass — by scan scope, not by a classifier heuristic. The fixture suite must still plant that exact
  shape and assert it passes, so a future widening of the scan surface to `.sh` files trips a test
  rather than silently flagging a correct line. State the by-scan-scope mechanism in the header so
  the exemption is not mistaken for an unimplemented classifier.
- **D4 — the identity divergence from `merge.lua` is accepted.** See Research Integration item 5.
- **D5 — the fragment-coverage identity key** is `(normalized invoked script path, event name,
  hook type)`, where normalization strips the anchor prefix (`"$CLAUDE_PROJECT_DIR"/.claude/`,
  `.claude/`, or a leading `/`) and keeps the remaining directory-qualified path as written — so
  `scripts/foo.sh` is compared as readily as `hooks/foo.sh`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A whole-file text grep false-positives on `root-files/settings.json`'s `_comment` field (demonstrated live) | H | H | Anchor every match on a `"command"` key. Phase 1 verification asserts the live corpus returns exit 0, which fails immediately if the `_comment` is matched. |
| Matching MCP `"command": "npx"` under `mcpServers` as a hook registration | M | M | For the jq-parsed checks, walk only `.hooks.<Event>[].hooks[]`. For the line-oriented checks, require the extracted token to end in `.sh`. Phase 1/3 verification on the live corpus (which contains the real `npx` entry) is the positive control. |
| Adding gate 21 silently breaks `test-verify-deploy-gate-selection.sh`, which hardcodes `seq 1 20` twice and `21` in its invalid-id list | H | H | Phase 5 widens the `--only-gate` range to 1-21 **and** updates that test in the same phase. This is the one file added to `file_scope` beyond the dispatch's four — see File Scope Note. |
| Porting `merge.lua`'s `hook_identity()` narrows the fragment check back to `hooks/`-only, regressing criterion 8 | M | M | Implement the identity independently (D5). Phase 4's fixture set includes a `scripts/foo.sh`-shaped root-files-only case, not only a `hooks/foo.sh`-shaped one, so the narrowing trips a test. |
| A fenced-JSON block in markdown is a JSON *fragment*, not a parseable document, so `jq` cannot read it | M | H | Use a line-oriented fenced-block state machine for the markdown check (Phase 2) and reserve `jq` for the settings files (Phase 3/4), which are complete valid JSON. |
| A deploy gate that fails open silently passes a bad deploy — the exact failure mode this task exists to prevent | H | L | Fail-closed `[[ ! -f lib/common.sh ]] → exit 2` guard above the `source`, mirroring all 11 sibling lints; criterion 5 is verified directly in Phase 6 by temporarily shadowing the library path. |
| A future doc legitimately needs to show the defective shape in a fenced JSON block to explain the anti-pattern | L | M | Phase 2 ships a file-level allowlist mechanism with mandatory inline reasons (the `lint-state-writer-boundary.sh` Layer-2 convention). It is seeded empty: no source-store markdown currently needs it (verified — only four `.md` files carry any `CLAUDE_PROJECT_DIR` text and all four are clean). |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel. Phases 2 and 3 are deliberately serialized
behind each other rather than run as one wave: both edit the single new lint script, so parallel
dispatch would collide on the same file. Phases 4 and 5 touch disjoint files (the fixture test vs.
`verify-deploy.sh` + `manifest.json` + the gate-selection test) and are genuinely parallel.

### Phase 1: Lint skeleton + Check A (path shape in settings surfaces) [COMPLETED]

**Goal**: Create `lint-hook-registration-paths.sh` with the full house-convention scaffold and the
first of four checks working end-to-end against the live corpus.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh`, modeled *(completed)*
      structurally on `lint-state-writer-boundary.sh` (348 lines): `#!/usr/bin/env bash`,
      `set -euo pipefail`, RED/GREEN/YELLOW/NC colors, `--verbose`/`--quiet`/positional `path...`
      argument loop, `SCRIPT_DIR` resolution.
- [x] Add the fail-closed library guard **above** the `source`: *(completed)*
      `[[ ! -f "${SCRIPT_DIR}/../lib/common.sh" ]] && { echo "ERROR: shared library not found…" >&2; exit 2; }`.
- [x] Copy `lint-state-writer-boundary.sh`'s `resolve_project_root()` *(completed)* (walks upward for a directory
      containing `agent-system/extensions`, falling back to `common_repo_root "$SCRIPT_DIR" 3`) so
      the script runs identically from the source-store and deployed copies.
- [x] Write the header comment block, which must state, in these terms: *(completed)* the exit-code contract
      (`0` clean / `1` violations / `2` script error); the **fail-closed vs. fail-open polarity
      contrast** (a deploy gate fails CLOSED so a broken gate cannot silently pass a bad deploy;
      a write-time hook fails OPEN so a broken guard cannot block every write — do not "correct"
      one to match the other); the accepted anchors per D1 including the `~/` rationale; the D3
      by-scan-scope reason `.sh` files are never scanned; the D2 existence-check exemption; the D4
      `merge.lua` identity divergence; and the task-364-D6 `settings.local.json` exclusion.
- [x] Enumerate the settings scan surfaces: *(completed)* `core/root-files/settings.json`,
      `core/merge-sources/settings-hooks.json`, and every `*/settings-hooks.json` and
      `*/settings-fragment.json` under the extensions root. **Exclude**
      `core/root-files/settings.local.json` explicitly, with the D6 reason inline.
- [x] Implement Check A: for each surface, select lines matching *(completed)* a `"command"[[:space:]]*:` key
      (never bare path text), extract the invoked script path — handling the nested
      `bash -c '…'` wrapper by finding the innermost invoked `*.sh` token rather than the outer
      `bash -c` — and classify. A line whose `bash -c` body invokes no `*.sh` at all (e.g.
      `core/root-files/settings.json` line 43's inline `permissionDecision` echo) is not a
      registration of a script and must not be flagged. Accept `/`-absolute,
      `"$CLAUDE_PROJECT_DIR"`-anchored, and `~/`-anchored per D1; everything else is a violation.
- [x] Emit `[VIOLATION] file:line: <text>` (red) and, under `--verbose`, *(completed)* `[EXEMPT] file:line:
      <reason> | <text>` (yellow). Close with a `====` banner summary and a `Fix:` footer naming
      the correct `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh` form and the source-store edit
      target.
- [x] `chmod +x` the new script. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the live corpus is clean under Check A. Re-derived at
plan-authoring time on 2026-10-07 by a key-anchored scan across all 13 settings surfaces: every
`"command"` value is `"$CLAUDE_PROJECT_DIR"`-anchored except one `bash -c` block at
`core/root-files/settings.json` line 43 that invokes no script path, and
`memory/settings-fragment.json`'s `"command": "npx"` which sits under `mcpServers`, not `hooks`.
The implementer confirms by running the finished Check A against the real tree and asserting
exit 0; a nonzero exit means either the corpus drifted or the `_comment`/MCP false positives are
live, and must be diagnosed, not suppressed.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - new file: scaffold,
  fail-closed guard, header contract, surface enumeration, Check A

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh --verbose`
  exits 0 against the live source store, and its `--verbose` output does **not** list
  `root-files/settings.json` line 2 (`_comment`) or `memory/settings-fragment.json`'s `npx` line
  as candidates at all.
- Piping a synthetic violating surface (`"command": "bash .claude/hooks/x.sh"`) via an explicit
  positional path argument exits 1 and names that file and line.
- `bash -n` clean; `shellcheck` reports no new errors if available.

---

### Phase 2: Check B — markdown registration templates [COMPLETED]

**Goal**: Extend the lint so a copy-paste hook registration template in source-store markdown
cannot teach the defective shape after the upstream fix landed.

**Tasks**:
- [x] Add a markdown scan surface: *(completed)* every `.md` file under the extensions root (default scan root),
      processed by a fenced-block state machine that tracks ` ```json ` open/close and considers
      only lines **inside** such a block. Do not attempt `jq` — these blocks are JSON *fragments*,
      not complete documents.
- [x] Inside a fenced JSON block, apply the identical *(completed)* `"command"`-key-anchored extraction and
      path classifier Check A uses (share one function; do not duplicate the regex), so the two
      checks cannot drift apart on what counts as an accepted anchor.
- [x] Require the surrounding block to look like a registration *(completed)* (a `"type": "command"` sibling
      within the block, or a `"command"` key inside a `hooks`/`matcher` structure) so an unrelated
      JSON example carrying a `command` field is not swept in.
- [x] Add the Layer-2 file-level allowlist mechanism *(completed)* (`EXCLUDED_FILES` array, repo-relative paths,
      **every entry carrying its reason inline** — a bare path list rots into an unauditable
      suppression file). Seed it empty, with a comment stating that no source-store markdown
      currently requires an entry and that any future entry must state why.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly four source-store markdown files carry hook
registration templates, all currently clean. Re-derived at plan-authoring time on 2026-10-07:
`nvim/context/project/neovim/guides/neovim-integration.md`,
`nvim/context/project/neovim/guides/tts-stt-integration.md`,
`nvim/context/project/neovim/hooks/wezterm-integration.md`, and
`core/context/troubleshooting/workflow-interruptions.md` are the only `.md` files under the
extensions root containing `CLAUDE_PROJECT_DIR`, and every `"command"` line in them is
`"$CLAUDE_PROJECT_DIR"`-anchored save `neovim-integration.md` line 34's deliberate `~/`-anchored
form. The implementer confirms by running the finished Check B over the real tree and asserting
exit 0 with line 34 reported as accepted (not exempted-by-allowlist).

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - add markdown
  fenced-JSON scan surface, shared classifier call, allowlist mechanism

**Verification**:
- Full run over the live source store exits 0; `--verbose` output shows the four markdown files
  scanned and `neovim-integration.md:34` classified as accepted under the D1 `~/` anchor.
- A synthetic markdown fixture with `"type": "command"` / `"command": "bash .claude/hooks/x.sh"`
  inside a ` ```json ` fence, passed as a positional path, exits 1 naming that file and line.
- The same defective string placed in markdown **outside** any fenced JSON block (prose) does not
  trigger a violation.

---

### Phase 3: Check C (fragment coverage) + Check D (script existence) [COMPLETED]

**Goal**: Gate the two structural defect classes — a registration unreachable by resync, and a
registration invoking a script that does not exist.

**Tasks**:
- [x] Build the registration inventory with real `jq` *(completed)* over each settings surface's
      `.hooks | to_entries[] | .key as $event | .value[].hooks[]` (these files are complete valid
      JSON, unlike the markdown fragments). Walk only under `.hooks`, never top-level, so
      `mcpServers`-scoped `"command"` fields cannot enter the inventory.
- [x] Implement the D5 identity normalization: *(completed)* strip a leading `"$CLAUDE_PROJECT_DIR"/.claude/`,
      `.claude/`, or `/` anchor and keep the remaining directory-qualified path as written, so
      `scripts/foo.sh` and `hooks/foo.sh` are both first-class identities. Key the identity on
      `(normalized path, event, type)`. Do **not** import or mirror `merge.lua`'s
      `hooks/`-anchored `hook_identity()` — see D4.
- [x] Implement Check C: compute the root-files identity set *(completed)* and the union of all fragment-surface
      identity sets; flag every identity present in the former and absent from the latter. A
      both-surfaces identity PASSES (the established fresh-install pattern). A fragment-only
      identity PASSES. Only root-files-only is a violation.
- [x] Phrase the Check C violation message **in the fragment's terms**: *(completed)* name the hook script and
      the fragment file it should be added to (`core/merge-sources/settings-hooks.json` for a core
      hook), so the fix is obvious from the message alone.
- [x] Implement Check D: for every invoked script path *(completed)* that is source-store-resolvable (a
      `"$CLAUDE_PROJECT_DIR"`-anchored or `.claude/`-relative `hooks/NAME.sh` or `scripts/NAME.sh`),
      resolve `NAME.sh` against every `agent-system/extensions/*/hooks/NAME.sh` (hooks are spread
      across each extension's own `hooks/` directory, not only `core/hooks/`) and, for a
      `scripts/`-shaped path, against the corresponding `scripts/` locations; fail naming file and
      line when it resolves nowhere. Skip `~/`-anchored and otherwise non-source-store-resolvable
      paths per D2.
- [x] Fold both checks' counts into the single summary banner *(completed)* and keep the one exit-code contract
      (any check's violation → exit 1).

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the corpus satisfies criteria 10 and 12 today.
Re-derived at plan-authoring time on 2026-10-07 by set-comparing hook script names across the
surfaces: **17** names appear in `core/root-files/settings.json`, **22** across the fragment
surfaces, **17** in both, **0** root-files-only (so criterion 10 holds now), and **5**
fragment-only (`detect-noop-bash.sh`, `mail-guard.sh`, `validate-evidence-append-only.sh`,
`validate-handoff-location.sh`, `validate-meta-write.sh`) which must all pass. Every invoked name
resolves to a file under some `agent-system/extensions/*/hooks/`, so criterion 12 holds now too.
These figures supersede the research report's carried "16 shared / 3 fragment-only" counts, which
omitted the `email` and `books` extension fragments. The implementer re-derives the same two sets
with the finished Check C and asserts the root-files-only set is empty and exit is 0.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - add jq-based
  registration inventory, D5 identity normalization, Check C, Check D, unified summary

**Verification**:
- Full run over the live source store exits 0; `--verbose` lists the five fragment-only identities
  as accepted and reports zero root-files-only identities.
- A synthetic fixture adding a root-files-only `"command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/zz-new.sh"`
  entry exits 1 with a message naming both `zz-new.sh` and the fragment file it belongs in.
- A synthetic fixture whose registration invokes `hooks/does-not-exist.sh` exits 1 naming file and
  line; a `~/`-anchored path to a nonexistent file does **not** exit 1 (D2).
- `memory/settings-fragment.json`'s `"command": "npx"` never appears in the inventory.

---

### Phase 4: Both-polarity fixture test suite [COMPLETED]

**Goal**: Lock every passing and failing shape the dispatch enumerates behind a test, so no later
widening or narrowing of the lint can regress a criterion silently.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` *(completed)*
      following `test-lint-directory-pathspec-boundary.sh`'s harness exactly: `set -uo pipefail`,
      `git rev-parse --show-toplevel` REPO_ROOT with a fixed-depth fallback, `resolve_candidate()`
      preferring the deployed `.claude/scripts/lint/` copy then the source-store sibling,
      `pass()`/`fail()`/`info()` counters, a `mktemp -d` WORKDIR with trap-based teardown, and an
      exit-code contract comment noting this is a test OF a lint (its exit code reports test
      success, not lint success). **No on-disk fixture files are committed.**
- [x] FAILING case: a direct `"command": "bash .claude/hooks/x.sh"` settings registration *(completed)*
      (criterion 1).
- [x] FAILING case: a CWD-relative path nested inside a `bash -c '…'` wrapper *(completed)*
      (criterion 1, second syntactic shape).
- [x] FAILING case: the line-118 shape *(completed)* — `"command": "bash scripts/claude-ready-signal.sh
      2>/dev/null || echo '{}'"` — which contains no `.claude/` and no `hooks/` at all
      (criterion 11). This case is the regression net against either rule re-anchoring on
      `.claude/` or on `hooks/`.
- [x] FAILING case: a defective registration template inside a ` ```json ` fence in markdown *(completed)*
      (criterion 6).
- [x] FAILING case: a root-files-only registration, asserted twice *(completed)* — once `hooks/`-shaped and once
      **`scripts/`-shaped** — with the message checked for both the hook script name and the
      fragment file name (criteria 8, 9).
- [x] FAILING case: a registration invoking a source-store script that does not exist *(completed)*
      (criterion 12).
- [x] PASSING case: the explicit-`cd` direct invocation, planted verbatim as a `.sh` fixture *(completed)* —
      `( cd "$repo" && … | bash .claude/hooks/please-grant.sh )` — asserting exit 0
      (criterion 7, per D3).
- [x] PASSING cases: the both-surfaces shape and the fragment-only shape (criterion 9); a *(completed)*
      `"$CLAUDE_PROJECT_DIR"`-anchored registration; a `~/`-anchored registration (D1); a
      `bash -c` block invoking no script at all; a `_comment` field quoting the correct form in
      prose (the demonstrated false-positive hazard); an `mcpServers`-scoped `"command": "npx"`;
      and a `settings.local.json` permission matcher carrying a relative path (D6 — out of scope,
      must pass).
- [x] `chmod +x` the test. *(completed)* No `run-all.sh` edit is needed — it discovers `tests/test-*.sh` by glob.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the fixture suite needs roughly 15 cases (7 failing,
8 passing) and lands at ~250-340 lines, in line with the nine sibling `test-lint-*.sh` suites
measured at 203-881 lines (median ~275) on 2026-10-07. The implementer confirms the real case
count and line count when the suite runs green; a materially larger suite is fine, a materially
smaller one means a case was dropped and must be reconciled against the twelve acceptance
criteria.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` - new file:
  both-polarity fixture suite

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` exits 0
  with every case reported `[PASS]` and a nonzero `$PASSED`.
- Deliberately inverting one failing fixture to the correct form makes that case report `[FAIL]`
  (the suite is proven to actually assert, not merely to run).
- No file is left behind under the repo after the run (`git status --short` unchanged).

---

### Phase 5: Gate 21 wiring, gate-range widening, manifest registration [COMPLETED]

**Goal**: Make the lint run in the real `verify-deploy.sh` battery and be installed by deploy —
criterion 3 requires an actual numbered gate, not mere manifest registration.

**Tasks**:
- [x] Add gate 21 to `agent-system/extensions/core/scripts/verify-deploy.sh` immediately after *(completed)*
      gate 20, modeled line-for-line on gate 12 (`lint-state-writer-boundary.sh`): the
      `if gate_selected 21; then` guard, `say "21. Hook registration path lint
      (lint-hook-registration-paths.sh --verbose)"`, `CURRENT_GATE="gate21"`, the
      `[ ! -d "$TARGET/agent-system/extensions" ]` → `[SKIP] … is a deploy consumer` branch, the
      `fail "… not found in source store"` branch, the
      `cd "$TARGET" && REPO_ROOT="$TARGET" bash … --verbose` capture, `pass`/`fail`, and the
      `FINDINGS_LIST+=("FINDING gate21 …")` `while read` loop over `grep -F '[VIOLATION]'`.
      Close with the trailing `say ""` and `fi`.
- [x] Widen the `--only-gate` range from 1-20 to 1-21 at **all four** sites in *(completed)*
      `verify-deploy.sh`: the two header-comment mentions (lines ~80 and ~86), the non-numeric
      error message, and the `-lt 1`/`-gt 20` bound check with its error string.
- [x] Update `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh`: *(completed)*
      change case (b)'s `seq 1 20` to `seq 1 21`, case (d)'s `seq 1 20` to `seq 1 21`, replace
      `"21"` with `"22"` in `invalid_cases`, and update the three "all 20 gates"/"all 20 gate
      headers" strings and the header comment at line 26 to 21. **Without this, adding gate 21
      breaks a currently-green test three ways** — see File Scope Note.
- [x] Register both new scripts in `agent-system/extensions/core/manifest.json` at their *(completed)*
      alphabetically-correct positions: `"lint/lint-hook-registration-paths.sh"` after
      `"lint/lint-directory-pathspec-boundary.sh"` (line ~136) and before
      `"lint/lint-json-channel-discipline.sh"`; `"tests/test-lint-hook-registration-paths.sh"`
      after `"tests/test-lint-directory-pathspec-boundary.sh"` (line ~225) and before
      `"tests/test-lint-json-channel-discipline.sh"`.
- [x] Confirm `manifest.json` remains valid JSON (`jq empty`). *(completed)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts gate 20 is currently the highest-numbered gate (so the
new one is 21) and that the `--only-gate` range appears at exactly four sites in
`verify-deploy.sh` plus three assertion sites and one comment in
`test-verify-deploy-gate-selection.sh`. Re-derived at plan-authoring time on 2026-10-07 by
grepping gate headers (`say "N. …"` runs 1-20) and `1-20`/`20` occurrences in both files.
The implementer re-greps both files before editing and reconciles any count difference rather
than assuming these positions; a missed site leaves either a valid gate id rejected or a test
silently asserting the wrong total.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - add gate 21; widen `--only-gate`
  range to 1-21 at all four sites
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` - widen
  cases (b) and (d) to 21, move the invalid-id probe from 21 to 22, update count strings
- `agent-system/extensions/core/manifest.json` - register the lint and its test in
  `installed_files`

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 21 .` runs gate 21 and
  prints exactly one gate header.
- `--only-gate 21` is accepted; `--only-gate 22` exits 2 with a named `ERROR: --only-gate:` error.
- `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` exits 0
  with all four cases passing.
- `jq empty agent-system/extensions/core/manifest.json` succeeds, and both new entries sit in
  alphabetical order within their arrays.

---

### Phase 6: Full-battery verification and criterion-5 fail-closed proof [COMPLETED WITH EXCLUSIONS]

**Goal**: Prove the complete gate set passes with the new gate present, and prove the fail-closed
polarity directly rather than by inspection.

**Tasks**:
- [x] Run the full `bash agent-system/extensions/core/scripts/verify-deploy.sh` battery (all 21
      gates) against this repo and confirm `PASS` with 0 failures, with gate 21 among the gates
      reported. *(completed: `--skip-slow` full run (gates 1-7, 9-21) shows 1 of 34 check(s)
      failed -- gate 13 (whole-tree orphan detection) naming `scripts/roadmap-integration.sh`,
      `scripts/tests/test-roadmap-argv-ceiling.sh`, `scripts/tests/test-roadmap-items-producer.sh`;
      gate 21 itself reports `[PASS]`. Gate 8 (`tests/run-all.sh`, the slow gate `--skip-slow`
      defers) run separately via `--fail-on-new`: 112 passed, 5 failed (4 EXPECTED against
      `known-failures.txt`, 1 NEW: `test-verify-deploy-context-budget.sh`). See the Reasoned
      Exclusions subsection below: both the gate-13 finding and the gate-8 NEW finding are traced
      to the same root cause -- a separate, concurrently in-flight task's unfinished quarantine of
      `roadmap-integration.sh` -- and are not this task's defect. 0 failures attributable to task
      365's own deliverable.)*
- [x] Prove criterion 5 empirically: invoke the lint with its shared library made unreachable
      (run a copy from a scratch directory whose `../lib/common.sh` does not exist) and confirm
      exit code **2** with the named `ERROR: shared library not found` message — never exit 0.
      Confirm the gate-21 wrapper surfaces that as a `fail`, not a pass. *(completed: direct
      invocation against a shadowed-library fixture exits 2 with the named error; the gate 21
      wrapper against the same fixture reports `[FAIL]`, overall `verify-deploy` exit 1 -- never a
      silent pass)*
- [x] Walk all twelve dispatch acceptance criteria against concrete evidence (a command run and
      its observed output per criterion) and record any that cannot be demonstrated. *(completed:
      all 12 criteria demonstrated -- see the Testing & Validation table below, now fully checked)*
- [x] Confirm `bash agent-system/extensions/core/scripts/tests/run-all.sh` discovers and passes
      the new fixture suite (glob discovery — no runner edit should have been needed; if one was,
      that is a finding). *(completed: confirmed from inside a completed live `run-all.sh
      --fail-on-new` invocation --
      `[run-all] [PASS] .../tests/test-lint-hook-registration-paths.sh` -- in addition to the
      earlier by-construction glob match and the standalone 18/0 run. No runner edit was needed.)*
- [x] Deploy the source store so the deployed `.claude/` copies exist, then re-run gate 21 to
      confirm it behaves identically invoked from either copy. *(completed: the deployed
      `.claude/scripts/lint/lint-hook-registration-paths.sh` and
      `.claude/scripts/tests/test-lint-hook-registration-paths.sh` are already byte-identical to
      their source-store originals (confirmed via `diff -q`) and gate 5's content-hash-equality
      check passes. Running the lint directly from the deployed copy
      (`bash .claude/scripts/lint/lint-hook-registration-paths.sh --verbose`) exits 0 with the
      identical corpus counts (12 settings surfaces, 923 markdown files, 50 accepted, 0
      violations) as the source-store invocation -- confirmed behaviorally identical from either
      copy.)*

**Timing**: 1 hour

**Depends on**: 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the battery runs 21 gates and that all twelve dispatch
acceptance criteria are demonstrable. The "21" is carried forward from Phase 5's own re-derivation
(gate 20 was the highest-numbered gate in `verify-deploy.sh` as measured on 2026-10-07) and is
only valid if Phase 5 landed exactly one new gate. The implementer confirms by counting the
`say "N. …"` gate headers in a full battery run rather than assuming 21, and reconciles the
criterion table against the dispatch's own numbered list rather than against this plan's
restatement of it.

**Files to modify**:
- none planned (verification-only phase; any file touched here is a defect fix traced back to the
  phase that introduced it)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) reports
  `[verify-deploy] PASS -- N check(s), 0 failure(s)` with gate 21 present.
- The library-shadowing run exits 2 with the named error (criterion 5).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes, with
  `test-lint-hook-registration-paths.sh` among the discovered suites.
- A written criterion-by-criterion table, all twelve marked satisfied with the evidencing command.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Full `verify-deploy.sh` battery reporting literal `0 failure(s)` | Gate 13 (whole-tree orphan detection) fails naming exactly three files -- `scripts/roadmap-integration.sh`, `scripts/tests/test-roadmap-argv-ceiling.sh`, `scripts/tests/test-roadmap-items-producer.sh` -- all three removed from `manifest.json`'s `installed_files` by a separate, concurrently in-flight task's own commits (`bc2205f0d core: quarantine roadmap-integration.sh and its test suites (phase 5/7)`, `9e3b1c5b8 core: complete the roadmap-integration.sh quarantine move (fixup)`), whose deployed copies have not yet been cleaned up (that task's own commit messages mark it "phase 5/7" and "fixup", i.e. unfinished). This is outside task 365's `file_scope` (none of the five scoped files touch `roadmap-integration.sh` or its deployment) and fixing it here would overwrite another task's in-flight work. Gate 8's one NEW failure (`test-verify-deploy-context-budget.sh`, not present in `known-failures.txt`) traces to the identical root cause: that suite's one full-battery "baseline fixture" invocation (a real `rsync -a` copy of the whole `agent-system/extensions/` tree) inherits the same three orphan files and fails gate 13 inside its own fixture, independent of gate 20 (the gate the suite actually tests) or anything task 365 changed. | `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow .` → `[verify-deploy] FAIL -- 1 of 34 check(s) failed`, the one failure being gate 13 naming the three files above; gate 21 reports `[PASS]`. Manual reproduction of `test-verify-deploy-context-budget.sh`'s exact fixture-build steps, run standalone against a `mktemp -d` copy, isolates the suite's "baseline fixture is not clean" failure to the identical `FINDING gate13` lines (plus an unrelated pre-existing `FINDING gate16` WARN) -- no `gate21` or `gate20` finding present. `git log --oneline -- '**/roadmap-integration.sh'` shows the quarantine commits as the most recent history for those paths, authored outside this task's dispatch chain. |

This exclusion satisfies the admission test: the item is specific and enumerated (the exact gate
and the exact three orphan files), it is not fixable within this task's own authority or
`file_scope` without overwriting a different task's in-flight commits, full evidence is recorded
above (a command run and its observed output), it does not block this task's own deliverable
(gate 21, the lint, and its fixture suite are all independently green), and the underlying result
is not "genuinely still outstanding" from THIS task's perspective -- it is provably owned by
another task's unfinished work, which will resolve it on its own completion.

---

## File Scope Note

The dispatch fixed `file_scope` to four files. This plan requires **one additional file**:

- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh`

This is not scope creep but a mechanical consequence of criterion 3. That test hardcodes
`seq 1 20` in case (b), `seq 1 20` in case (d), and `"21"` in its `invalid_cases` list. Adding a
21st gate — which criterion 3 requires — turns a currently-green test red three ways unless it is
updated in the same change. Adding it as an **exact file** (not a directory) preserves the stated
rationale of the dispatch's narrowing revision, which replaced two directory entries precisely
because `agent-system/extensions/core/scripts/` and `.../scripts/tests/` collided against 35 and
22 other non-terminal tasks respectively. A single exact file adds no comparable collision surface.

Resulting `file_scope` (5 entries):

```
agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh
agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh
agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh
agent-system/extensions/core/scripts/verify-deploy.sh
agent-system/extensions/core/manifest.json
```

## Testing & Validation

- [x] Criterion 1: the lint fails, naming file and line, on a CWD-relative `.claude/` registration
      (both the direct and the `bash -c`-nested shape) — Phase 4 failing cases 1 and 2. *(verified)*
- [x] Criterion 2: the lint passes on the live corpus — Phases 1, 2, 3 verification. *(verified:
      exit 0, 12 settings surfaces, 923 markdown files, 50 accepted, 0 violations)*
- [x] Criterion 3: the lint runs as numbered gate 21 in `verify-deploy.sh` — Phase 5, Phase 6.
      *(verified: `--only-gate 21 .` reports PASS standalone; gate 21 also reports `[PASS]` inline
      within the full `--skip-slow` battery run (gates 1-7, 9-21); and the lint behaves
      identically invoked from the deployed `.claude/scripts/lint/` copy)*
- [x] Criterion 4: the fixture test covers both the passing and the violating case — Phase 4.
      *(verified: 18 assertions, 6 failing + 9 passing shapes, 18 passed / 0 failed; inversion
      sanity check confirms the suite is not vacuously green)*
- [x] Criterion 5: a deliberately absent or broken lint library causes a nonzero exit — Phase 6,
      proven empirically by shadowing the library path, not by inspection. *(verified: direct exit
      2, gate-21 wrapper reports [FAIL], never a silent pass)*
- [x] Criterion 6: a defective registration template in a fenced JSON block in markdown fails,
      naming file and line — Phase 4 failing case 4. *(verified)*
- [x] Criterion 7: the explicit-`cd` direct-invocation shape is a PASSING fixture case — Phase 4.
      *(verified)*
- [x] Criterion 8: a root-files-only registration fails, naming the hook script and the fragment
      file it belongs in — Phase 4 failing case 5. *(verified, both hooks/-shaped and
      scripts/-shaped)*
- [x] Criterion 9: both-surfaces and fragment-only are PASSING cases; root-files-only is FAILING
      — Phase 4. *(verified)*
- [x] Criterion 10: the lint passes on the corpus given task 364's six moved registrations —
      Phase 3 (root-files-only set is empty today). *(verified: live-corpus Check C root-files-only
      identity count is 0)*
- [x] Criterion 11: a relative hook command path containing no `.claude/` fails, with the
      line-118 shape as a fixture FAILING case — Phase 4 failing case 3. *(verified)*
- [x] Criterion 12: a registration invoking a nonexistent source-store script fails, naming file
      and line — Phase 4 failing case 6, Phase 3. *(verified)*
- [x] Full `verify-deploy.sh` battery passes with 0 failures attributable to task 365 — Phase 6.
      *(verified with one reasoned exclusion -- see Phase 6's `#### Reasoned Exclusions`
      subsection: `--skip-slow` full run reports `1 of 34 check(s) failed`, the single failure
      being gate 13's orphan detection against three files belonging to a separate, concurrently
      in-flight task's unfinished quarantine of `roadmap-integration.sh`; gate 21 itself reports
      `[PASS]`. Gate 8 (`run-all.sh`) run separately with `--fail-on-new`: 112 passed, 5 failed (4
      EXPECTED per `known-failures.txt`, 1 NEW traced to the identical root cause). 0 failures
      trace to this task's own deliverable.)*
- [x] `run-all.sh` discovers and passes the new fixture suite — Phase 6. *(verified by
      construction -- matches run-all.sh's own `scripts/tests/test-*.sh` discovery glob -- by a
      direct standalone run, 18 passed / 0 failed -- and now also from inside a completed live
      `run-all.sh --fail-on-new` invocation:
      `[run-all] [PASS] .../tests/test-lint-hook-registration-paths.sh`)*
- [x] No file outside the five-entry `file_scope` is modified (`git status --short` review before
      each commit, per `context/standards/git-staging-scope.md`). *(verified: `git status
      --short` before this phase's closing commit shows only this task's own five-entry
      `file_scope` files plus the always-staged `specs/TODO.md`/`specs/state.json`/task-directory
      paths; no other source-store file was touched by this dispatch)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` (new, executable)
- `agent-system/extensions/core/scripts/tests/test-lint-hook-registration-paths.sh` (new,
  executable)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gate 21 + widened `--only-gate` range)
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` (range
  assertions widened to 21)
- `agent-system/extensions/core/manifest.json` (two `installed_files` entries)
- `specs/365_lint_cwd_relative_hook_path_registrations/summaries/01_hook-registration-path-lint-summary.md`
  (written at implementation completion)

## Rollback/Contingency

Every phase commits per-substep, so the rollback granularity is one green sub-step. Contingencies,
cheapest first:

1. **A check false-positives on the live corpus.** Fix forward: tighten that one check's extraction
   or add an allowlist entry *with its reason inline*. Never widen the accept condition to make a
   violation disappear — that defeats the gate.
2. **Gate 21 destabilizes the battery.** Revert only the gate-wiring commit (Phase 5) with
   `git revert <sha>`; the lint and its fixture suite remain useful and tested standalone, and
   re-wiring becomes a one-commit follow-up. This is the preferred containment: it keeps criteria
   1-2 and 4-12 satisfied while criterion 3 is re-attempted.
3. **A wholesale revert is needed.** The task's footprint is three new/edited scripts plus a JSON
   registration, all additive; `git revert` of this task's commits in reverse order restores the
   prior state with no migration to undo. If uncommitted work must be discarded first, follow
   `context/contracts/recovery.md`'s rollback rung for the snapshot-then-rollback invocation shape
   (including its out-of-scope override flag) before running any destructive git command — do not
   emit a bare precautionary snapshot as a routine start-of-phase step.
