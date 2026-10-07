# Implementation Plan: Task #348

- **Task**: 348 - Write-time PreToolUse Write|Edit hook enforcing append-only evidence files, the books extension first hook and its registration path
- **Status**: [NOT STARTED]
- **Effort**: 5.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/348_append_only_evidence_write_time_hook/reports/01_append-only-evidence-write-time-guard.md
- **Artifacts**: plans/01_append-only-evidence-write-time-hook.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add the books extension's first hook: a PreToolUse `Write|Edit` guard
(`validate-evidence-append-only.sh`) that refuses any write which alters or removes a line already
present in `books/book-convention-evidence/NN-*.md`, while permitting a pure append, a new
`NN-*.md`, `README.md`, and every out-of-scope path. The work is four files in the source store
(hook, fixture suite, settings fragment, manifest wiring) plus a real deploy into the consumer
repository that proves the registration landed bare inside the existing exact-string `"Write|Edit"`
matcher block and that the deployed hook refuses a real modification of a real evidence file. No
new prose or pattern document is produced; the three required facts travel inline in the rejection
message.

### Research Integration

Every "verified during task creation" premise was re-confirmed in the source tree by the research
report, and three of them drive design decisions directly: `merge.lua`'s hook-event-array merge
joins per **exact-string** matcher (so the fragment must spell `"Write|Edit"` byte-identically to
core's existing block), `loader.lua`'s `INSTALL_ONCE_ROOT_FILES` makes `.claude/settings.json`
skip-if-exists (so registration can only arrive through `merge_targets.settings`), and `.tool_name`
is available top-level in the PreToolUse payload (so Write-vs-Edit branching is explicit rather
than inferred from which keys happen to be populated). The research also closed the fragment-naming
question mechanically: `specs/state.json`'s `file_scope` for this task already locks all four paths,
including `agent-system/extensions/books/settings-hooks.json`, so that question is not re-opened
here.

Re-confirmed independently during planning, beyond the report:

- The consumer repository is live at `/home/benjamin/Projects/Logos/Verification`; its
  `.claude-extensions.json` loads `books` with `source_dir` pointing at this repo's
  `agent-system/extensions/books`, so a deploy from here reaches it.
- Its deployed `.claude/settings.json` already holds a `PreToolUse` block whose matcher is exactly
  `"Write|Edit"` carrying `bash .claude/hooks/validate-no-task-references.sh` — the block this
  registration must join. The same file also holds a **separate** legacy `"Write"` block (an inline
  `permissionDecision: allow` command), which is a live demonstration that a near-miss spelling
  produces an independent block rather than joining an existing one.
- `books/book-convention-evidence/` holds `00-index.md` through `19-*.md` plus `README.md`;
  `01-book-identity-and-membership.md`'s longest line measures **7814** characters, confirming the
  incident shape the buried-modification fixture must reproduce.
- The live `check-evidence-append-only.sh` header already carries the corrected rewrite remedy and
  the monotonicity measurement; its scope is `NN-*.md` under `books/book-convention-evidence/` with
  `README.md` excluded (`EVDIR` at line 57, the `case` exclusions at lines 92 and 100). It is an
  input, not a target.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:

- A write that alters or deletes any line already committed in an evidence file is refused with
  exit 2 and a stderr message carrying all three required facts inline, including the
  buried-in-a-7800-character-line shape.
- A pure append (Write and Edit), a new `NN-*.md`, `README.md`, and every out-of-scope path are
  allowed, demonstrated by fixture.
- The trailing-uncommitted-entry question and the registration-target question are each ruled on
  explicitly, with the reason recorded in the artifact that carries the mechanism.
- The books extension gains a complete, durable deployment path for its first hook:
  `provides.hooks`, a `provides.scripts` tests entry, and a `merge_targets.settings` block.
- The deployed hook is proven to refuse a real modification of a real committed evidence file after
  a real deploy, and the registration is proven bare and joined to the existing matcher block.

**Non-Goals**:

- No new context/pattern document, and no restatement of the append-only rule in new prose. The
  task fails if its primary deliverable is a pattern document.
- No edit to `books/scripts/check-evidence-append-only.sh` or its remediation message.
- No machine-readable immutability markers, fences, or delimiters added into the evidence files.
- No fix to the email extension's wrapped registration or to lean's unregistered hook.
- No broadening of the hook beyond `books/book-convention-evidence/NN-*.md`.
- No extension of `verify-deploy.sh`'s hardcoded registration-gate pair list.
- No registration in `.claude/settings.local.json`.

## Rulings

Three questions the dispatch requires to be settled in writing. Each ruling is recorded here and,
where it governs behavior, restated in one line inside the artifact that implements it (the hook's
own header comment or the manifest `_comment`) — never in a new document.

**Ruling 1 — registration target: `.claude/settings.json`, bare.** Confirmed, not overturned.
`settings.local.json` is gitignored in the consumer repo, so a guard over a tracked, shared
archival record would live in a per-clone untracked file and would not reach a fresh clone at all;
`verify-deploy.sh`'s registration gate also inspects `settings.json` only, making a
`settings.local.json` registration invisible to the verifier. Core's own `merge_targets.settings`
`_comment` draws exactly this line ("required core functionality rather than personal
MCP/permission preference"), and an append-only guard is required functionality by that test. Bare
registration (no `2>/dev/null || echo '{}'`) because that wrapper converts exit 2 into exit 0 and
silently disables the block. The `.syncprotect` alternative is rejected: it would freeze the whole
settings file against every future core update to win one entry, and install-once already protects
those two files.

**Ruling 2 — trailing uncommitted entry: Option B, git-aware.** Only lines present in `HEAD`'s
version of the file are immutable; the uncommitted tail may be edited freely. Reason: this matches
exactly what the commit-time gate can and cannot punish. An uncommitted deletion is cheaply
remediable in the working tree and never requires a history rewrite, so refusing it buys nothing,
while refusing it would push an author toward appending a correction entry for a typo in an entry
appended seconds earlier — which degrades the record the guard exists to protect. **Fallback**:
when `git show HEAD:<relpath>` cannot produce a version (not a checkout, no such path in HEAD, a
shallow or detached state in which the lookup fails), compare against the current on-disk content
instead — the Option A prefix test, which is strictly stricter. This fallback is a well-understood
branch of the predicate and is **not** the fail-open case; the two must not be conflated.

**Ruling 3 — the fail-open contract's two separate guards, mapped onto this hook's real dependency
surface.** The inherited contract requires the missing-library and failed-to-source cases to be
guarded separately, for the reason the precedent documents: under `set -euo pipefail` an unguarded
failure aborts before the fallthrough can reach `exit 0`. This hook sources **no** shared library —
nothing in `scripts/lib/` provides an evidence-path or append-only predicate, and creating a
library solely to manufacture a sourcing-failure mode would add a fifth file outside the locked
`file_scope` for no functional benefit. The contract is therefore honored as two separately guarded
internal-error classes over the dependency the hook actually has:

1. **presence** — `jq` not on `PATH`: stderr `WARNING`, `exit 0`.
2. **usability** — `jq` present but the captured stdin does not parse as JSON (or the payload
   extraction fails): a separate guard, its own stderr `WARNING` naming which guard fired,
   `exit 0`.

The dispatch's own fixture list corroborates this mapping: it requires "a missing-dependency case
failing OPEN with exit 0". Each guard gets its own `if`, its own message, and its own fixture.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Matcher string not byte-identical to `"Write\|Edit"` creates a second, permanently undeletable registration block (the merge is add-only) | H | M | Copy the literal matcher string from `agent-system/extensions/core/merge-sources/settings-hooks.json` rather than retyping it; Phase 5 asserts exactly one `"Write\|Edit"` block in the deployed file and two hook objects inside it |
| A line-oriented implementation (diff, split-on-newline, per-line compare) passes every fixture except the one that models the real incident, which was buried inside a single ~7814-character line | H | M | Implement the predicate as pure byte-string prefix/suffix tests only; the buried-long-line fixture is a required case, authored as a regression probe against a future line-splitting rewrite |
| A broken or over-firing guard blocks every Write/Edit in a consumer repo | H | L | Both fail-open guards per Ruling 3, each fixture-proven; the scope early-exit returns 0 before any git or content work, so a non-matching path cannot reach the predicate at all |
| Hook copied but not registered, or registered but not firing — the silent half-deployment the lean extension already exhibits | H | M | Phase 5 verifies the three legs independently: file present with execute bit, registration present and bare and joined, and the deployed copy refusing a real payload against a real committed evidence file |
| `verify-deploy.sh`'s registration gate checks only three hardcoded core event:script pairs, so this registration is not regression-protected by tooling | M | H | Out of scope by ruling; recorded as a known limitation in Phase 5 with no widening of scope to close it |
| Latency added to every Write/Edit in a books-loaded repo | M | M | Scope match is a pure string test performed before any subprocess; `git` runs only for an in-scope path |
| `books/manifest.json` overlaps the file_scope of a held task restructuring the books context corpus | L | M | No dependency edge; the regions are disjoint (a `provides.hooks` entry, a `provides.scripts` entry, one new `merge_targets` block vs. context/index/claudemd restructuring). Whichever lands second rebases |
| Re-deploy re-adds a duplicate hook object | L | L | `merge_hook_event_array`'s deep-equal existence check makes a byte-identical hook object a no-op on re-merge; Phase 5 deploys twice and asserts the count is unchanged |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the Hook Script [NOT STARTED]

**Goal**: `agent-system/extensions/books/hooks/validate-evidence-append-only.sh` exists, is
executable, is shellcheck-clean, and implements the scope match, the Ruling 2 predicate, the
rejection message, and the Ruling 3 fail-open guards.

**Tasks**:
- [ ] Create `agent-system/extensions/books/hooks/` and author the script with
      `#!/usr/bin/env bash` and `set -euo pipefail`, resolving its own location via
      `HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` so nothing depends on the tool's
      cwd (inherited contract 3).
- [ ] Write the header comment: what the hook blocks, that it blocks via exit code 2 + stderr and
      never `permissionDecision: deny`, that it MUST be registered bare and why the
      `2>/dev/null || echo '{}'` wrapper silently disables the block, that it fails open on an
      internal error, Ruling 2 and its fallback in one or two lines, and one line naming
      `check-evidence-append-only.sh` as the companion commit-time gate. Cite by filename and
      concept only — no task numbers anywhere in this file.
- [ ] Add fail-open guard 1 (presence): if `command -v jq` fails, print a `WARNING:` line naming
      this hook and `jq`, then `exit 0`.
- [ ] Parse the payload: read stdin (with the precedent's `[ -t 0 ]` / `CLAUDE_TOOL_INPUT` env
      fallback), then extract `.tool_name`, `.cwd`, `.tool_input.file_path`,
      `.tool_input.content`, `.tool_input.old_string`, `.tool_input.new_string`,
      `.tool_input.replace_all`. Add fail-open guard 2 (usability) as its own separate `if`: if the
      captured stdin does not parse as JSON, print a distinct `WARNING:` line naming guard 2 and
      `exit 0`.
- [ ] Early exits, all `exit 0` and silent: no `file_path` resolved; no content captured.
- [ ] Resolve the absolute path: if `file_path` is not already absolute, join it onto `.cwd`.
      Normalize without requiring the file to exist.
- [ ] Scope match on the resolved absolute path, performed **before** any subprocess: the path must
      end in `books/book-convention-evidence/<two digits>-<anything>.md`, and a basename of exactly
      `README.md` is excluded. Any non-match exits 0 silently, so the hook is inert in every repo
      that lacks the directory.
- [ ] A path that does not yet exist on disk is a creation: `exit 0` (creation of a new `NN-*.md`
      is allowed).
- [ ] Compute the immutable baseline per Ruling 2: derive the repo root from the resolved path
      (`git -C "$(dirname "$ABS_FILE")" rev-parse --show-toplevel`), compute the path relative to
      that root, and capture `git show HEAD:<relpath>`. On any failure of that chain, fall back to
      the current on-disk content and record in a comment that this fallback is stricter and is not
      fail-open.
- [ ] Implement the predicate as **byte-string tests only** — no `diff`, no newline splitting, no
      per-line arrays:
      - `tool_name == "Write"`: allowed only if the baseline is a byte-exact **prefix** of
        `.tool_input.content`.
      - `tool_name == "Edit"`: allowed only if `old_string` is a byte-exact **suffix** of the
        baseline **and** `new_string` begins with `old_string`. Record in a comment that this is
        deliberately conservative: it needs no simulation of Edit semantics and no reasoning about
        `replace_all` uniqueness, and it is stricter than necessary in a few edge cases rather than
        looser in any.
      - Any other `tool_name`: `exit 0`.
- [ ] On refusal, emit the multi-line stderr message carrying all three facts **inline** — the file
      is append-only; the commit-time counter is monotonic, so a later restore cannot undo a
      committed deletion and the only remedy is a history rewrite; append a dated entry instead —
      plus one line naming `check-evidence-append-only.sh` as the companion gate. Then `exit 2`.
- [ ] `chmod +x` the script.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/books/hooks/validate-evidence-append-only.sh` - new file: the whole hook

**Verification**:
- `shellcheck agent-system/extensions/books/hooks/validate-evidence-append-only.sh` is clean per
  `context/standards/shell-strict-mode.md`.
- `bash -n` parses; the file is executable.
- Hand smoke test from a scratch git repo laid out as `books/book-convention-evidence/01-x.md`: a
  constructed Write payload that truncates the committed content exits 2 with a message containing
  all three facts; a payload appending to it exits 0; a payload naming a path outside the directory
  exits 0; a payload naming `README.md` exits 0.
- `bash .claude/scripts/check-task-references.sh` (or a `grep -nEi 'task[ _-]*#?[0-9]'` over the
  new file) finds no task-number citation.

---

### Phase 2: Fixture Suite, Behavioral Cases [NOT STARTED]

**Goal**: `agent-system/extensions/books/scripts/tests/test-validate-evidence-append-only.sh`
exists with the books harness shape and every required behavioral case green.

**Tasks**:
- [ ] Author the suite modeled on `scripts/tests/test-books-gate.sh`: `set -uo pipefail` (Class B —
      report every case, never abort on the first failure), `SCRIPT_DIR` via `BASH_SOURCE`, a
      `HOOK="${SCRIPT_DIR}/../../hooks/validate-evidence-append-only.sh"` target, `PASSED`/`FAILED`
      counters with `pass`/`fail`/`info`, a prerequisite check that the hook is executable, a `jq`
      prerequisite check, a `WORKDIR="$(mktemp -d)"` with `trap 'rm -rf "$WORKDIR"' EXIT`, and the
      closing `echo "$PASSED passed, $FAILED failed"` / `[[ "$FAILED" -eq 0 ]] || exit 1`.
- [ ] Add a header comment stating the suite's discipline: it drives the real hook as a subprocess
      with a constructed PreToolUse JSON payload on stdin, never sources it to call internals, and
      carries forgery probes per the books extension's forgery-probe discipline.
- [ ] Add fixture builders: `make_repo DIR` (a `git init -q` repo with a committed
      `books/book-convention-evidence/01-decision.md` and `README.md`, author identity set locally
      so the commit succeeds in any environment) and `payload TOOL FILE ...` emitting the JSON
      shape (`tool_name`, `cwd`, `tool_input`) via `jq -n` so quoting is never hand-rolled.
- [ ] Case: in-place modification of an existing committed line via Edit — exit 2.
- [ ] Case: the same refusal's stderr carries all three facts — assert on the message, not only the
      exit code: append-only, the monotonic/history-rewrite fact, and the append-a-dated-entry
      instruction, plus the companion gate's filename.
- [ ] Case: deletion of an existing committed line via Write (content with a line removed) —
      exit 2.
- [ ] Case: pure append via Write (committed content, byte-exact, plus a new trailing entry) —
      exit 0.
- [ ] Case: pure append via Edit (`old_string` = the file's trailing text, `new_string` = that
      text plus a new entry) — exit 0.
- [ ] Case: creation of a new `NN-*.md` that does not exist on disk — exit 0.
- [ ] Case: Edit to `README.md` in the same directory, modifying an existing line — exit 0.
- [ ] Case: a path outside the evidence directory, modifying an existing line — exit 0.
- [ ] Case: Ruling 2 asserted explicitly — an in-place edit to the file's own trailing,
      **not-yet-committed** appended entry is ALLOWED (exit 0); and its companion, that the same
      edit reaching back into a **committed** line in the same file is still refused (exit 2), so
      the case binds the HEAD baseline rather than the on-disk one.
- [ ] Case: the Ruling 2 fallback — the same in-place modification in a directory that is **not**
      a git checkout is refused (exit 2) by the on-disk prefix test, proving the fallback is
      stricter and not fail-open.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts eleven behavioral cases over four fixture repositories.
Both counts are hypotheses: confirm at implementation time by counting the `pass`/`fail` call sites
the suite actually emits and the `make_repo` invocations it actually makes, and correct this line
rather than forcing the code to match it.

**Files to modify**:
- `agent-system/extensions/books/scripts/tests/test-validate-evidence-append-only.sh` - new file:
  harness, fixture builders, and the behavioral cases

**Verification**:
- `bash agent-system/extensions/books/scripts/tests/test-validate-evidence-append-only.sh` reports
  `0 failed` and exits 0.
- `shellcheck` clean on the new suite.
- Every case's expectation is asserted against the real hook subprocess; no case sources the hook
  or reimplements its predicate.

---

### Phase 3: Forgery Probes, Fail-Open Cases, and the Buried-Long-Line Case [NOT STARTED]

**Goal**: the suite cannot pass against a stubbed predicate, both fail-open guards are proven, and
the incident's own shape is covered.

**Tasks**:
- [ ] Add a `probe_expect_broken NAME ACTUAL EXPECTED_FROM_REAL_CASE` helper matching
      `test-books-gate.sh`'s: it PASSES when the stubbed run does **not** reproduce the real case's
      expectation.
- [ ] Add a probe harness that copies the hook into the workdir and stubs **one** predicate per
      probe via a targeted `sed` substitution, then drives the stubbed copy with the same payload
      the real case used.
- [ ] Probe: stub the modification predicate to always-allow; assert the modification-refusal
      case's exit-2 expectation then fails.
- [ ] Probe: stub the scope match to always-match; assert the out-of-scope ALLOW case's exit-0
      expectation then fails (the complementary admit half — a probe suite of refusals alone cannot
      distinguish a correct refusal from a predicate that refuses everything).
- [ ] Probe: stub the HEAD-baseline lookup to return the on-disk content; assert the Ruling 2
      uncommitted-tail ALLOW case then fails, proving that case genuinely binds the HEAD baseline.
- [ ] Fail-open case 1 (presence): run the hook with a `PATH` from which `jq` is absent against the
      refusal payload — exit 0 with a `WARNING` on stderr naming the missing dependency.
- [ ] Fail-open case 2 (usability): run the hook with malformed (non-JSON) stdin — exit 0 with a
      distinct `WARNING` on stderr, proving the second guard is separate from the first.
- [ ] Buried-long-line case: build a fixture whose committed evidence file contains a single line
      of several thousand characters with an archival marker string embedded mid-line; drive a Write
      payload that is byte-identical except for that embedded string — assert exit 2. Comment that
      this is a regression guard against a future line-splitting rewrite, and that the hook
      deliberately contains no line-length handling of its own.
- [ ] Companion admit case for the long line: the same multi-thousand-character file with a new
      entry appended and the long line untouched — exit 0.

**Timing**: 1.0 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts three forgery probes, two fail-open cases, and two
long-line cases. Confirm the probe count at implementation time against the predicates the hook
actually ships (one probe per predicate is the standard's bar, so a hook that ends up with four
distinct predicates needs four probes); correct this line rather than under-probing to match it.

**Files to modify**:
- `agent-system/extensions/books/scripts/tests/test-validate-evidence-append-only.sh` - append the
  probe helper, the probes, the fail-open cases, and the long-line cases

**Verification**:
- The full suite reports `0 failed` and exits 0.
- Each probe's stub is confirmed to have actually applied (the `sed` substitution changed the copy)
  before its assertion runs, so a probe cannot pass by failing to stub anything.
- `shellcheck` clean.
- Every predicate the hook ships has at least one probe, per
  `context/project/books/standards/forgery-probe-discipline.md`.

---

### Phase 4: Manifest Wiring and the Settings Fragment [NOT STARTED]

**Goal**: the books extension declares the hook, the test, and a durable registration surface.

**Tasks**:
- [ ] Create `agent-system/extensions/books/settings-hooks.json` carrying **only** the PreToolUse
      registration: one `hooks.PreToolUse` array entry whose `matcher` is the literal string copied
      from `agent-system/extensions/core/merge-sources/settings-hooks.json`, with a single hook
      object `{"type": "command", "command": "bash .claude/hooks/validate-evidence-append-only.sh"}`
      — bare, with no `2>/dev/null || echo '{}'`.
- [ ] `agent-system/extensions/books/manifest.json`: change `provides.hooks` from `[]` to
      `["validate-evidence-append-only.sh"]`.
- [ ] `agent-system/extensions/books/manifest.json`: append
      `"tests/test-validate-evidence-append-only.sh"` to the existing `provides.scripts` array,
      matching the flat spelling its sibling test entries already use.
- [ ] `agent-system/extensions/books/manifest.json`: add a `merge_targets.settings` block with
      `"source": "settings-hooks.json"`, `"target": ".claude/settings.json"`, and a `_comment`
      recording Ruling 1 in the style core's own `_comment` uses on that same key — why the tracked
      file rather than `settings.local.json`, that the registration must stay bare, that the matcher
      string must remain byte-identical to core's or a second block appears, and that the merge is
      add-only so renaming this script would leave a stale registration in already-synced repos.
- [ ] Confirm no other manifest key needs touching (no new `data`, `root_files`, or `index` entry;
      the hook is a flat `provides.hooks` file copy with an execute bit and nothing else).

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: three manifest edits (one `provides.hooks` value, one `provides.scripts`
append, one new `merge_targets.settings` block) plus one new fragment file. Confirm at
implementation time by diffing `manifest.json` and checking that the diff touches exactly those
three regions.

**Files to modify**:
- `agent-system/extensions/books/settings-hooks.json` - new file: the bare PreToolUse registration
- `agent-system/extensions/books/manifest.json` - `provides.hooks`, `provides.scripts`, and a new
  `merge_targets.settings` block

**Verification**:
- `jq -e . agent-system/extensions/books/settings-hooks.json` and
  `jq -e . agent-system/extensions/books/manifest.json` both succeed.
- `jq -r '.hooks.PreToolUse[0].matcher' agent-system/extensions/books/settings-hooks.json` is
  byte-identical to
  `jq -r '.hooks.PreToolUse[] | select(.hooks[0].command | test("validate-no-task-references")) | .matcher' agent-system/extensions/core/merge-sources/settings-hooks.json`
  (compare with `cmp`, not by eye).
- The fragment's command string contains no `||` and no `2>/dev/null`.
- `jq -r '.provides.hooks[], .merge_targets.settings.target' agent-system/extensions/books/manifest.json`
  shows the hook filename and `.claude/settings.json`.
- No task-number citation in either file.

---

### Phase 5: Deploy, Prove Registration and Firing, Record the Residuals [NOT STARTED]

**Goal**: the hook is live in the consumer repository — file copied with its execute bit,
registration bare and joined to the existing matcher block, and the deployed copy proven to refuse
a real modification of a real committed evidence file.

**Tasks**:
- [ ] Capture the before-state of the consumer repo's registration:
      `jq '.hooks.PreToolUse' /home/benjamin/Projects/Logos/Verification/.claude/settings.json` and
      `git -C /home/benjamin/Projects/Logos/Verification status --short .claude/settings.json`.
- [ ] Deploy: `bash .claude/scripts/deploy-headless.sh /home/benjamin/Projects/Logos/Verification`
      from this repo. If that invocation errors because this repo's own deployed core tree is stale,
      fall back to the source-store copy
      (`bash agent-system/extensions/core/scripts/deploy-headless.sh /home/benjamin/Projects/Logos/Verification`)
      or to the consumer repo's own deployed copy with no target argument, and record which
      invocation was used.
- [ ] Verify the file copy: `/home/benjamin/Projects/Logos/Verification/.claude/hooks/validate-evidence-append-only.sh`
      exists and is executable (`test -x`).
- [ ] Verify the registration is **bare**: the deployed command string equals
      `bash .claude/hooks/validate-evidence-append-only.sh` exactly, with no `||` and no
      `2>/dev/null`.
- [ ] Verify it **joined** the existing block rather than creating a second one: the deployed
      `hooks.PreToolUse` contains exactly **one** entry whose matcher is `Write|Edit`, and that
      entry's `hooks` array contains both `validate-no-task-references.sh` and the new hook.
      (The file's pre-existing separate `"Write"` block is unrelated and must be left untouched.)
- [ ] Prove idempotence: deploy a second time and assert the hook-object count inside the
      `Write|Edit` block is unchanged.
- [ ] Prove the deployed hook **fires** against a real evidence file: pick a committed file under
      `/home/benjamin/Projects/Logos/Verification/books/book-convention-evidence/`, confirm it is
      clean in `git status`, and drive the **deployed** hook as the harness would — bare
      `bash .claude/hooks/validate-evidence-append-only.sh` with a PreToolUse JSON payload on stdin
      whose `cwd` is the consumer repo root and whose `tool_input` alters one existing line.
      Assert exit 2 and the three facts in stderr. Then drive the same hook with a pure-append
      payload for the same file and assert exit 0. Neither invocation writes to the file, so the
      evidence file is never modified by this verification.
- [ ] Confirm the evidence files were not touched:
      `git -C /home/benjamin/Projects/Logos/Verification status --short books/book-convention-evidence/`
      is empty.
- [ ] Re-run the companion gate:
      `bash /home/benjamin/Projects/Logos/Verification/books/scripts/check-evidence-append-only.sh`
      still reports 0 blocking findings.
- [ ] Record the two residuals, each in one line, in the hook's own header comment (not a new
      document): (a) `verify-deploy.sh`'s registration gate checks only three hardcoded core
      event:script pairs, so this registration is not regression-protected by tooling — a generic
      "every `provides.hooks` entry is registered somewhere" check is a separate concern; (b) the
      harness's own dispatch of this hook can only be observed from an interactive session whose
      project directory is the consumer repo, so the proof above drives the deployed copy with a
      real payload instead. Include the one-line reproduction recipe for an operator who wants the
      end-to-end observation: open a session in the consumer repo and attempt an in-place Edit of a
      committed evidence file.

**Timing**: 1.0 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- none planned in the source store; this phase deploys and verifies. The hook header's two residual
  lines are the only authored change, in
  `agent-system/extensions/books/hooks/validate-evidence-append-only.sh`

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) — the complete gate set — run against
  the consumer repo; `deploy-headless.sh` invokes it by default, so capture and read its output
  rather than assuming it ran clean.
- The four assertions above (file present and executable; command bare; exactly one `Write|Edit`
  block containing both hooks; count unchanged after a second deploy) each pass, each read out of
  the deployed `.claude/settings.json` with `jq`.
- The deployed hook exits 2 on the real-file modification payload and 0 on the real-file append
  payload.
- `books/book-convention-evidence/` is clean in `git status` afterwards, and
  `check-evidence-append-only.sh` reports 0 blocking findings.
- The full fixture suite still reports `0 failed`.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/books/scripts/tests/test-validate-evidence-append-only.sh`
      reports `0 failed`.
- [ ] Every required case from the dispatch is present: committed-line modification refused;
      committed-line deletion refused; pure append via Write allowed; pure append via Edit allowed;
      new `NN-*.md` allowed; `README.md` allowed; out-of-scope path allowed; the Ruling 2 behavior
      asserted explicitly in both directions; a missing-dependency case failing open; and the
      buried-in-a-multi-thousand-character-line modification refused.
- [ ] Forgery probes present, one per predicate, each with its complementary admit case where one
      exists, per `context/project/books/standards/forgery-probe-discipline.md`.
- [ ] `shellcheck` clean on both new shell files per `context/standards/shell-strict-mode.md`.
- [ ] `jq -e .` clean on both JSON files.
- [ ] The deployed registration is bare, in `.claude/settings.json`, joined to the single
      `Write|Edit` block.
- [ ] The deployed hook refuses a real modification of a real committed evidence file.
- [ ] `check-evidence-append-only.sh` reports 0 blocking findings in the consumer repo afterwards.
- [ ] Net pattern-document count does not increase: no file added under
      `agent-system/extensions/books/context/**` or `agent-system/extensions/books/rules/**`.
- [ ] No task-number citation in any file under `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/books/hooks/validate-evidence-append-only.sh` (new, executable)
- `agent-system/extensions/books/scripts/tests/test-validate-evidence-append-only.sh` (new,
  executable)
- `agent-system/extensions/books/settings-hooks.json` (new)
- `agent-system/extensions/books/manifest.json` (modified: `provides.hooks`, `provides.scripts`,
  `merge_targets.settings`)
- A redeployed `.claude/` tree in `/home/benjamin/Projects/Logos/Verification` carrying the hook and
  its registration
- `specs/348_append_only_evidence_write_time_hook/summaries/01_*-summary.md` at implementation close

## Rollback/Contingency

- Source-store rollback is a plain revert of the four files; nothing in them is stateful. Take a
  non-reverting checkpoint (`bash .claude/scripts/git-snapshot.sh 348 --no-revert`) before Phase 5
  if the working tree carries other in-flight work.
- Consumer-repo rollback needs care because the settings merge is **add-only**: the deploy will not
  remove the registration on its own. To back the registration out, remove the books hook object
  from the `Write|Edit` block in `/home/benjamin/Projects/Logos/Verification/.claude/settings.json`
  by hand (that file is tracked, so `git diff` shows exactly what to drop), delete
  `.claude/hooks/validate-evidence-append-only.sh`, and revert the source-store manifest change so
  the next deploy does not re-add it.
- If the deployed hook over-fires (refuses a legitimate append), the immediate mitigation is to
  remove the one hook object from the deployed `Write|Edit` block — no other repository behavior
  depends on it — then fix the predicate and redeploy. Do not wrap the registration as a
  workaround: the wrapper is the failure mode this task exists to avoid.
- If Phase 5's deploy cannot reach the consumer repo at all, Phases 1-4 still stand on their own
  (fixture-proven, shellcheck-clean, fully wired) and the task closes `[PARTIAL]` with Phase 5's
  deploy verification named as the outstanding item — never closed as complete on the strength of
  the fixtures alone, since a registered-but-not-firing hook is the exact failure mode this task's
  acceptance targets.
