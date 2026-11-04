# Implementation Plan: Task #282

- **Task**: 282 - Write-time PreToolUse hook blocking record-versioning language, registered bare so exit 2 survives
- **Status**: [IMPLEMENTING]
- **Effort**: 4.0 hours
- **Dependencies**: None outstanding (the rule/taxonomy/library, the repo-wide lint, and the hook-registration path convention are all closed and present in the source store)
- **Research Inputs**: specs/282_record_versioning_write_time_hook/reports/01_write-time-hook-research.md
- **Artifacts**: plans/01_write-time-record-version-hook.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build the write-time enforcement consumer for `rules/no-record-versioning-in-deliverables.md`: a
`PreToolUse` hook on `Write|Edit` that blocks a write introducing forbidden record-version
language into a deliverable, driven entirely by the existing shared pattern library
(`scripts/lib/record-version-patterns.sh`), plus its fixture test, its registration on both
settings surfaces, and the `manifest.json` wiring. The hook is a thin consumer: it defines no
pattern, no exemption rule, and no tier of its own, exactly as the taxonomy's Enforcement
section already prescribes. The edit target throughout is the source store
`agent-system/extensions/core/`, never the deployed `.claude/` tree.

All work lands in the source store; the final phase redeploys and confirms the registration is
live, bare, and free of the false-positive failure mode the task's acceptance criteria name as
worse than having no hook at all.

### Research Integration

The research report resolves every open design question this plan depends on, and these five
findings are load-bearing here:

1. **Advisory tier at write time: silent.** The hook matches `rv_grep_blocking` only and never
   calls `rv_grep_advisory`. Planning measured this empirically against the live corpus with the
   deployed lint: the repository currently carries **809 ADVISORY** findings outside `specs/**`.
   A hook that emitted a note per advisory finding would fire on a large fraction of all prose
   writes in this repository and would train every reader to ignore it.
2. **Registration must land on BOTH settings surfaces.** `root-files/settings.json` is
   install-once (its own `_comment` says so) and never reaches an already-deployed repository;
   `merge-sources/settings-hooks.json` is the only mechanical propagation path into a live
   `.claude/settings.json`, declared by `manifest.json`'s `merge_targets.settings`. The sibling
   task-reference hook is registered in both files today. This is additionally enforced
   mechanically: `scripts/lint/lint-hook-registration-paths.sh` Check C fails a registration that
   is reachable only through `root-files/settings.json`.
3. **The pipeline order is `strip_durable_axis_lines` then `strip_exempt_regions` then
   `rv_grep_blocking`.** The first step has no counterpart in the task-reference library, so a
   too-literal port of the sibling hook would omit it — and omitting it is precisely what would
   block an ordinary `docs/` write citing a toolchain pin, a schema filename, or a CI cache-key
   segment.
4. **Edit-path scope is payload-only.** `strip_exempt_regions` in this library is a flat
   `in_block` toggle with no nesting concept, so the sibling hook's occurrence-counting,
   depth-aware, disk-reconstructing Edit path has no analogous requirement here, and none of the
   acceptance criteria exercise disk reconstruction. The residual blind spot is recorded in Risks
   below and must be stated in the hook's own header rather than left implicit.
5. **Fail-open polarity is the hook's contract and is the opposite of the deploy lints'.** A
   broken guard must never block every write in the repository. The sibling guards a missing
   library and an unsourceable library separately because, under `set -e`, an unguarded `.`
   failure aborts before any fallthrough.

Planning also measured the pre-change BLOCKING baseline so the implementer can attribute
findings correctly: **3 BLOCKING** findings exist today, all three H1 page titles under
`lua/neotex/plugins/tools/himalaya/docs/`, already declared out of scope by the pattern library's
own comment. They are untouched by this task.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap alignment was
consulted.

## Goals & Non-Goals

**Goals**:
- A `PreToolUse` hook that blocks a `Write`/`Edit` introducing BLOCKING-tier record-version
  language into a non-`specs/**` deliverable, via exit code 2 plus an actionable stderr message.
- Inheritance of the three named sibling contracts verbatim: exit-2 blocking (never
  `permissionDecision: deny`), fail-open on a library that is missing, unsourceable, or stale,
  and `BASH_SOURCE`-relative library resolution.
- A recorded, documented write-time posture for the taxonomy's advisory tier, consistent between
  the hook header and the taxonomy document.
- A fixture test driving the hook as a real subprocess over every acceptance case, including the
  durable-axis false-positive guard.
- Bare registration on both settings surfaces plus `manifest.json` wiring, verified against the
  deployed form.

**Non-Goals**:
- Any change to `scripts/lib/record-version-patterns.sh` beyond a comment correction (no new
  pattern, no nesting support in `strip_exempt_regions`, no tier change).
- Region-aware Edit-path reconstruction (deliberately out of scope; see Risks).
- Sweeping the three pre-existing BLOCKING findings under `lua/neotex/plugins/tools/himalaya/docs/`.
- Wiring `check-record-versioning.sh` into `verify-deploy.sh` as a gate; it stays a standalone
  utility.
- Any change to the ADVISORY patterns or to how the repo-wide lint reports them.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Omitting `strip_durable_axis_lines` blocks ordinary writes citing a toolchain pin, schema filename, or CI cache key | H | M | Phase 1 implements the library's documented 5-step Usage order; Phase 2 adds a durable-axis-only fixture proving the step is wired in the hook, not merely present in the library; Phase 5 probes it live |
| Registration lands only in `root-files/settings.json` and never reaches the live `.claude/settings.json` | H | M | Phase 3 edits both surfaces and verifies with `lint-hook-registration-paths.sh` Check C, which fails exactly this shape; Phase 5 greps the deployed form |
| Registration gets wrapped in `2>/dev/null \|\| echo '{}'` by copying the PostToolUse neighbors in the same file | H | M | Phase 3 states the command string verbatim and verifies it; Phase 5 greps the deployed entry for the absence of `\|\| echo` |
| Payload-only Edit scan false-positives on an edit landing inside a file-wide `version-ok:begin`/`:end` region whose markers sit outside the edited span | M | L | Accepted and recorded in the hook header and the taxonomy's Enforcement section as a known, bounded blind spot with the `version-ok` inline marker as the author's immediate escape hatch; a real observed instance is separate future scope, not silently absorbed here |
| The fixture test's own literal BLOCKING fixtures make the test file unblockable-to-edit once the hook is live, and add new BLOCKING findings to the repo-wide lint | M | H | Phase 2 marks every fixture line carrying literal blocking content with a trailing `# version-ok` bash comment naming the test-fixture category, exactly as the sibling test does with its own marker; the marker lives in the bash comment and never enters the string value the hook receives |
| The hook's own header, quoting forbidden examples, makes the hook file unblockable-to-edit after it goes live | M | M | Phase 1 either avoids literal forbidden examples in the header or encloses them in a `version-ok` marked region; Phase 5's live probes include an edit to the hook file itself |
| A stale library (sources cleanly but predates the two-tier API) silently produces a false-clean verdict | M | L | Phase 1 adds a `declare -F` guard over all five required functions with fail-OPEN polarity (the opposite of the lint's fail-closed polarity, which is deliberate and documented in both files); Phase 2 adds a stale-library fixture |
| The complete gate set in Phase 5 reports pre-existing failures unrelated to this task | L | M | Phase 5 attributes each finding against the recorded pre-change baseline (3 BLOCKING record-version findings; whatever `verify-deploy.sh` reports before the change) rather than treating any red as caused here |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the Hook [COMPLETED]

**Goal**: `agent-system/extensions/core/hooks/validate-no-record-versioning.sh` exists, is
shellcheck-clean, and implements the three inherited contracts plus the library's documented
5-step call order.

**Tasks**:
- [x] Read `hooks/validate-no-task-references.sh` end to end, including its `scan_and_block` *(completed)*
      helper and its non-fatal `system-defect-record.sh` call, before writing anything.
- [x] Create the hook with `set -euo pipefail` (Class A per `context/standards/shell-strict-mode.md`). *(completed)*
- [x] Write the header recording, explicitly: blocking via exit 2 plus stderr and never *(completed)*
      `permissionDecision: deny` (documented-buggy for allow-listed `Write`/`Edit`; upstream
      issues 4669, 13214, 18312); the bare-registration requirement and the
      `2>/dev/null || echo '{}'` trap; fail-open polarity and its deliberate contrast with the
      deploy lints' fail-closed polarity; the advisory-silent write-time posture and its reason;
      and the payload-only Edit scope with its named blind spot.
- [x] Resolve the library `BASH_SOURCE`-relative: `HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, *(completed)*
      `LIB="$HOOK_DIR/../scripts/lib/record-version-patterns.sh"`.
- [x] Guard all three degraded-library cases, each with a `WARNING:` on stderr and `exit 0`: *(completed)*
      file missing (`[ ! -f "$LIB" ]`), source failure (`if ! . "$LIB"`), and a `declare -F`
      sweep over `is_exempt_path`, `strip_durable_axis_lines`, `strip_exempt_regions`,
      `rv_grep_blocking`, `rv_grep_advisory`.
- [x] Add `# shellcheck disable=SC1090` above the dynamic source line. *(completed)*
- [x] Parse stdin as the sibling does: `jq '.tool_input // {}'` with a `CLAUDE_TOOL_INPUT` *(completed)*
      env-var fallback for the flat shape; no resolvable `file_path` means `exit 0`.
- [x] Call `is_exempt_path "$FILE"` before any content scan; exempt means `exit 0`. *(completed)*
- [x] Discriminate Write from Edit by field presence, never by `tool_name`: `has("content")` *(completed)*
      selects the Write payload, `has("new_string")` without `content` selects the Edit payload.
- [x] Scan the selected payload through `strip_durable_axis_lines`, then `strip_exempt_regions`, *(completed)*
      then `rv_grep_blocking "$FILE"`. Never call `rv_grep_advisory`.
- [x] On a match, print a multi-line actionable stderr message naming *(deviation: altered -- the system-defect-record.sh call was omitted; see hook's own DEVIATION comment and progress file)*
      `.claude/rules/no-record-versioning-in-deliverables.md`, stating the durable-anchor
      alternative, naming the `version-ok` / `version-ok:begin` / `version-ok:end` escape hatch,
      calling `system-defect-record.sh` non-fatally as the sibling does, then `exit 2`.
      Otherwise `exit 0` silently.
- [x] Keep the hook's own file lint-clean: avoid literal forbidden examples in the header, or *(completed)*
      enclose them in a `version-ok` marked region with a reason naming the taxonomy category.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The file is new, sourced by nothing and registered on no settings
surface until Phase 3, so `shellcheck agent-system/extensions/core/hooks/validate-no-record-versioning.sh`
(gate 22's own tool) plus `bash -n` and hand-piped stdin smoke payloads is the complete covering
check at this point.

**Scope Hypothesis**: This phase is hypothesized to need no part of the sibling hook's Edit-path
disk reconstruction and to land at roughly 110-150 lines including the header. Confirm at
implementation time by checking the finished pipeline against the library's own documented 5-step
Usage order in its header, and by confirming no helper in the hook re-implements any exemption,
pattern, or tier decision.

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-no-record-versioning.sh` - create

**Verification**:
- `shellcheck agent-system/extensions/core/hooks/validate-no-record-versioning.sh` exits 0.
- `bash -n` on the file exits 0.
- Hand-piped smoke: a markdown payload carrying an unmarked bare-parenthesized heading label
  exits 2 with a non-empty stderr message naming the rule file.
- Hand-piped smoke: a payload whose only version language is a dotted toolchain pin, a
  `-v2.md` schema filename, and a `pnpm-v1-` cache-key segment exits 0.
- Hand-piped smoke: the blocking payload at a `specs/**` `file_path` exits 0.
- Hand-piped smoke: a payload carrying only bare past-tense vocabulary with no adjacent `vN`
  token exits 0 and prints nothing.

---

### Phase 2: Fixture Test and Lint/Hook Scope Agreement [COMPLETED]

**Goal**: `scripts/tests/test-validate-no-record-versioning.sh` drives the hook as a real
subprocess over every acceptance case, and the lint/hook scope-agreement case its sibling suite
flagged as temporarily omitted is restored.

**Tasks**:
- [x] Create the suite modeled structurally on `scripts/tests/test-validate-no-task-references.sh`: *(completed)*
      a `mktemp -d` workdir with a `trap EXIT` cleanup, the hook and
      `scripts/lib/record-version-patterns.sh` copied byte-for-byte to the exact relative layout
      the hook expects (`<workdir>/hooks/...` sourcing `<workdir>/scripts/lib/...`), synthetic
      `PreToolUse` payloads built with `jq -n --arg` so quoting is safe, and assertions on exit
      code (2 = blocked, 0 = allowed) and stderr emptiness, never on stdout.
- [x] Use one of the two sanctioned harness shapes per `scripts/lint/lint-test-harness-adoption.sh`: *(completed: local pass/fail/info)*
      either local `pass()`/`fail()`/`info()` definitions or sourcing `lib/common.sh` and calling
      `common_test_pass`/`common_test_fail`/`common_test_info` — never bare calls with neither.
- [x] Blocking cases (expect exit 2 plus non-empty, rule-naming stderr): an unmarked *(completed)*
      bare-parenthesized heading label on a markdown path; a supersession clause carrying a `vN`
      token within the same clause; an Edit-shaped payload (`old_string`/`new_string`) whose
      `new_string` carries blocking content.
- [x] Allowed cases (expect exit 0): the same blocking content at a `specs/**` path, both *(completed)*
      relative and absolute-prefixed; an advisory-only payload (bare past-tense vocabulary, no
      adjacent `vN`); blocking content inside an inline `version-ok` marked line and inside a
      `version-ok:begin`/`version-ok:end` region; a durable-axis-only payload exercising all
      three axes (toolchain pin, schema filename, CI cache-key segment); a non-markdown path
      whose `#`-prefixed comment line carries a `vN` token, proving the heading sub-branches stay
      excluded off markdown.
- [x] Degraded-library cases (expect exit 0 plus non-empty warning stderr): a fixture workdir *(completed)*
      holding only the hook and no `scripts/lib` directory at all; and a fixture whose copied
      library is deliberately truncated so it sources cleanly but no longer defines
      `rv_grep_blocking`.
- [x] Marker hygiene: give every fixture line carrying literal blocking content a trailing *(completed)*
      `# version-ok` bash comment whose reason names the test-fixture category, mirroring how the
      sibling suite handles its own marker. The comment is stripped as a whole raw line by the
      library's parser and never becomes part of the shell string value the hook receives.
- [x] Restore the lint/hook scope-agreement case in `scripts/tests/test-check-record-versioning.sh`: *(completed)*
      drive both `check-record-versioning.sh` and the hook over a shared fixture set and fail on
      any BLOCKING-verdict disagreement for a given path-plus-content pair, mirroring the
      task-reference sibling suite's equivalent case. Remove that suite's header note saying the
      case was omitted because the hook did not exist.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: Both touched paths resolve through `scripts/lib/suite-selection-lib.sh`
to exactly two suites, so `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-no-record-versioning.sh,test-check-record-versioning.sh`
is the covering check for this phase's edits.

**Scope Hypothesis**: The acceptance cases above are hypothesized to need 12-16 assertions and no
Edit-path disk-reconstruction helper. Confirm by enumerating the finished suite's assertions
against the case list in this phase and the acceptance criteria, and by confirming each
degraded-library fixture asserts on both the exit code and non-empty stderr.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-no-record-versioning.sh` - create
- `agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` - restore the
  scope-agreement case; drop the header note about its omission

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-no-record-versioning.sh,test-check-record-versioning.sh`
  reports every suite green.
- `shellcheck` clean on both touched suites.
- The deployed lint, scoped to the new suite file
  (`bash .claude/scripts/check-record-versioning.sh <path>`), reports 0 BLOCKING — proving the
  fixture marker hygiene holds.

---

### Phase 3: Registration and Manifest Wiring [COMPLETED]

**Goal**: The hook is registered bare on both settings surfaces and declared in `manifest.json`,
so a fresh install and an already-deployed repository both pick it up.

**Tasks**:
- [x] `manifest.json`: add `"validate-no-record-versioning.sh"` to `provides.hooks`, beside the *(completed)*
      existing `"validate-no-task-references.sh"` entry, preserving the array's existing ordering
      convention.
- [x] `manifest.json`: add `"tests/test-validate-no-record-versioning.sh"` to `provides.scripts`, *(completed)*
      beside the existing `"tests/test-validate-no-task-references.sh"` entry. These are two
      different arrays; the hook and the test do not go in the same one.
- [x] `root-files/settings.json`: append one `{"type": "command", "command": ...}` object to the *(completed)*
      `hooks` array of the existing `PreToolUse` matcher `"Write|Edit"` that already carries the
      task-reference hook, in that file's multi-line formatting. The command is exactly
      `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/validate-no-record-versioning.sh` — bare, with no
      `2>/dev/null || echo '{}'` wrapper. The `PostToolUse` entries in the same file do use that
      wrapper; do not copy them.
- [x] `merge-sources/settings-hooks.json`: add the identical registration to its own `PreToolUse` *(completed)*
      `"Write|Edit"` matcher block, in that file's compact single-line formatting. This is the
      surface that propagates into an already-deployed `.claude/settings.json`.
- [x] Confirm both JSON files still parse (`jq . <file> >/dev/null`). *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: The registration changes a surface whose consumers span `manifest.json`,
both settings files, and the deploy merge, so the enumerated one-hop check is
`bash agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh --verbose`
(Check A path shape, Check C fragment coverage, Check D script existence) together with
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-hook-registration-paths.sh,test-manifest-scripts-sync.sh,test-deploy-propagation.sh`.

**Scope Hypothesis**: Four edits across three files, all additive, with no reordering or
reformatting of neighboring entries. Confirm with `git diff --stat` on the three files showing
only insertions plus the minimal JSON punctuation changes additions require.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - add the hook to `provides.hooks` and the test to `provides.scripts`
- `agent-system/extensions/core/root-files/settings.json` - bare registration in the `Write|Edit` PreToolUse matcher
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - the same bare registration, compact form

**Verification**:
- `jq . ` succeeds on both settings files and on `manifest.json`.
- `bash agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh --verbose`
  exits 0; in particular Check C does not report the new registration as root-files-only.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-hook-registration-paths.sh,test-manifest-scripts-sync.sh,test-deploy-propagation.sh`
  reports every suite green.
- A direct grep of both registration lines shows no `|| echo` and no `2>/dev/null` on the new
  entry.

---

### Phase 4: Documentation Truth-Up [COMPLETED]

**Goal**: The taxonomy's Enforcement section and the pattern library's header describe the
enforcement surface as it actually is, and the advisory-silent posture is stated identically in
the taxonomy and in the hook header.

**Tasks**:
- [x] Rewrite `context/standards/record-version-exemptions.md`'s Enforcement section to state, as *(completed)*
      current fact: both consumers exist; their paths; that the repo-wide lint is a standalone
      utility rather than a `verify-deploy.sh` gate, so the hook is the automatic enforcement
      surface; the advisory-silent write-time posture and its reason, worded consistently with
      the hook's header; and the payload-only Edit scope with its named blind spot and the
      `version-ok` marker as the author's escape hatch.
- [x] Write that section without draft-history language about the document itself and without *(completed)*
      task-number citations, per `rules/no-record-versioning-in-deliverables.md` and
      `rules/no-task-references-in-deliverables.md` — this file is a deliverable outside
      `specs/**` and is subject to both.
- [x] Correct the pattern library's own header comment, which still describes both consumers as *(completed)*
      planned, to describe them as existing. Comment text only; no code change.
- [x] Read the finished Enforcement section against the hook's header side by side and confirm *(completed)*
      the two cannot be read as disagreeing about the advisory tier or the Edit-path scope.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Both edits are confined to markdown prose and a shell comment block with
no executable surface, covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-version-patterns.sh,test-check-record-versioning.sh`
plus the doc-lint and task-reference gate subset with an explicit source-store target,
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`.

**Files to modify**:
- `agent-system/extensions/core/context/standards/record-version-exemptions.md` - rewrite the Enforcement section
- `agent-system/extensions/core/scripts/lib/record-version-patterns.sh` - header comment only: both consumers now exist

**Verification**:
- Diff read-through confirming every changed hunk in the library file lies inside the header
  comment block.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`
  reports both selected gates green.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-version-patterns.sh,test-check-record-versioning.sh`
  green.
- `bash .claude/scripts/check-record-versioning.sh` scoped to each touched path reports 0
  BLOCKING.

---

### Phase 5: Deploy, Live Confirmation, and Full Gate [NOT STARTED]

**Goal**: The registration is live in the deployed tree in its bare form, the hook behaves
correctly against real writes including the named false-positive case, and the complete gate set
is green.

**Tasks**:
- [ ] Record the pre-change gate baseline before deploying, so any red in the final gate run can
      be attributed rather than assumed: the deployed record-versioning lint currently reports 3
      BLOCKING (all three H1 page titles under `lua/neotex/plugins/tools/himalaya/docs/`,
      out of scope here) and 809 ADVISORY.
- [ ] Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked with the Bash
      tool's `timeout` parameter raised to 600000 per `context/patterns/external-process-wait.md`.
- [ ] Confirm `.claude/hooks/validate-no-record-versioning.sh` exists in the deployed tree and
      `.claude/settings.json`'s `PreToolUse` `Write|Edit` matcher carries the new entry.
- [ ] Grep the deployed command string for this entry and confirm the absence of `|| echo` and of
      `2>/dev/null` on it.
- [ ] Live probe (the acceptance criterion's named worst case): an ordinary `Write` to a scratch
      file under a `docs/`-style path whose only version language is durable-axis — a toolchain
      pin, a schema filename, and a CI cache-key segment — is NOT blocked. Remove the scratch
      file afterwards.
- [ ] Live probe: a `Write` of unmarked blocking content to a scratch non-`specs/**` path IS
      blocked, and the stderr message names the rule file and the marker escape hatch. Remove the
      scratch file afterwards.
- [ ] Live probe: the same blocking content written to a path under `specs/**` is allowed.
- [ ] Live probe: an `Edit` to the new hook file itself and to the new fixture test file is not
      blocked, confirming the self-hygiene decisions in Phases 1 and 2 hold against the live hook.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Attribute any finding
      against the recorded baseline; do not treat a pre-existing failure as introduced here.

**Timing**: 1.0 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- none planned (deployment and verification only; the deployed `.claude/` tree is regenerated, never hand-edited)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set, including gate 2 (hook
  registrations), gate 5 (manifest parity), gate 8 (shell test suites), gate 13 (orphan
  detection), gate 21 (hook registration path lint), and gate 22 (shellcheck) — reports green,
  or each non-green finding is explicitly attributed to the recorded pre-change baseline.
- The deployed registration grep shows the bare command form with no wrapper.
- All four live probes behave as specified above.

---

## Testing & Validation

- [ ] `shellcheck` clean on the hook and on both touched test suites.
- [ ] `run-all.sh --only test-validate-no-record-versioning.sh,test-check-record-versioning.sh` green.
- [ ] Fixture coverage present for: a blocking finding denied with exit 2 and an actionable
      rule-naming stderr message; a `specs/**` path allowed; an advisory-only finding allowed
      silently; marker-exempted content allowed; a durable-axis-only payload allowed; an absent
      library failing open with exit 0 plus a warning; a stale library failing open with exit 0
      plus a warning.
- [ ] `lint-hook-registration-paths.sh --verbose` exits 0, with Check C satisfied by the
      merge-source registration.
- [ ] The deployed `.claude/settings.json` entry for this hook is bare — no `|| echo`, no
      `2>/dev/null`.
- [ ] An ordinary write carrying only durable-axis version language is not blocked, confirmed
      live after deployment.
- [ ] No task-number references introduced in any deliverable outside `specs/**`.
- [ ] `verify-deploy.sh` complete gate set green, or every finding attributed to the recorded
      baseline.

## Artifacts & Outputs

- `agent-system/extensions/core/hooks/validate-no-record-versioning.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-validate-no-record-versioning.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` (scope-agreement case restored)
- `agent-system/extensions/core/manifest.json` (two array entries)
- `agent-system/extensions/core/root-files/settings.json` (bare registration)
- `agent-system/extensions/core/merge-sources/settings-hooks.json` (bare registration)
- `agent-system/extensions/core/context/standards/record-version-exemptions.md` (Enforcement section)
- `agent-system/extensions/core/scripts/lib/record-version-patterns.sh` (header comment only)
- A redeployed `.claude/` tree carrying the live registration

## Rollback/Contingency

Every change is additive and confined to the source store plus a regenerated deploy, so rollback
is a revert of the source-store edits followed by a redeploy.

- **If the live hook blocks a legitimate write** (the highest-cost failure mode): remove the two
  registration entries from `root-files/settings.json` and `merge-sources/settings-hooks.json`,
  redeploy, and the hook is inert while the file itself stays in place for diagnosis. This is a
  smaller, faster, and more targeted rollback than reverting the whole task, and it is the first
  action to take.
- **If a phase's edits need reverting mid-task**: take a non-reverting checkpoint first
  (`bash .claude/scripts/git-snapshot.sh 282 --no-revert`) so the working tree is preserved, then
  revert the specific files.
- **If the complete gate set is red for reasons attributable to this task**: fix forward against
  the named gate rather than discarding uncommitted work, per `context/contracts/recovery.md`'s
  recovery ladder.
