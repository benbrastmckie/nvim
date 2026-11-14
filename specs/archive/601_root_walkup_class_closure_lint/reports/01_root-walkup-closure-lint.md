# Research Report: Task #601

- **Task**: 601 - Close the class of invocation-path-dependent repo-root resolution in test
  suites with a durable lint
- **Started**: 2026-11-11
- **Completed**: 2026-11-11
- **Effort**: ~1 session
- **Dependencies**: None
- **Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/lint/, scripts/lib/common.sh,
  scripts/gate-registry.data, scripts/verify-deploy.sh), git history of the remedy task, direct
  shell execution to confirm path-resolution arithmetic
- **Artifacts**: specs/601_root_walkup_class_closure_lint/reports/01_root-walkup-closure-lint.md
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The remedy task's own summary names the exact lint this task is asked to build:
  `lint-test-root-resolution.sh`, explicitly modeled on `lint-test-harness-adoption.sh` — that
  model is directly reusable (same scan-scope definition, same allowlist mechanism, same
  standalone-script-plus-fixture-test shape) and should be followed, not reinvented.
- The discriminator the dispatch asks for ("discriminate the genuinely-passes-both case") is
  already named, in prose, by the remedy's own plan Non-Goals: a fixed-depth walk-up is the
  **sanctioned** shape when it sits behind a `git rev-parse --show-toplevel` (or equivalent
  validated-candidate) attempt that is tried *first*; it is the **forbidden** shape only when it
  is the unconditional, sole computation with no git-first or validated-candidate guard. This is
  mechanically checkable per-file without needing to understand *why* a given suite happens to
  tolerate the wrong answer.
- `test-verify-deploy-gate-selection-crash-net.sh` is the one confirmed "legitimately passes both
  despite carrying the shape" case, and it is NOT a case the discriminator above resolves
  automatically — it genuinely has no git-first guard and genuinely computes a wrong root from
  the deployed path, but tolerates it because its own assertions are a crash-net (presence of
  errors only) rather than a correctness check against real content. This needs a narrow,
  by-path, reasoned allowlist entry — the exact mechanism `lint-test-harness-adoption.sh` already
  uses for its own one false-positive case.
- The sweep this research pass ran (same "measure every walk-up in the corpus" method the remedy
  task used) found **three additional, currently-live instances** of the forbidden shape beyond
  the five+two the remedy task already named and migrated: `test-state-write-spill-names.sh`
  (`core/scripts/`), `test-source-store-path-lib.sh` (`core/scripts/tests/`), and
  `test-orchestrate-context-growth.sh` (`core/scripts/tests/`, three call sites). Two of the
  three silently mask the exact failure-masking hazard the task description warns about
  (a real-state-pollution guard and a real-specs-leak guard both degrade to a silent false
  "PASS" when run from the deployed copy). These should be migrated to
  `common_test_repo_root`/`common_test_ext_root` as part of landing this lint, so the lint can
  launch at zero violations as the task requires.
- `lint-test-harness-adoption.sh` itself is **not** currently wired into `verify-deploy.sh`/
  `gate-registry.data` as a deploy gate — it exists only as a standalone script with its own
  unit-test fixture suite. The new lint can follow that same standalone precedent, or be
  registered as gate 29 in `gate-registry.data` (next free id after 28); either is viable, and
  the choice is an open implementer decision this report surfaces rather than resolves.

## Context & Scope

Task 601 asks for a durable, mechanical lint that forbids a specific shape in shell test suites:
an **unconditional, fixed-depth parent walk** (`cd "$SOME_DIR/../../../.."`) used as the sole
means of computing the repository root (or extensions root), with no git-first or validated-
candidate fallback. The remedy task (589, `589_test_suite_repo_root_walk_up_depth`) already
migrated the known instances to the existing `common_test_repo_root`/`common_test_ext_root`
helpers in `scripts/lib/common.sh` and explicitly declared this lint a Non-Goal/follow-up. This
research pass's job was to determine: the exact shape to detect, how to discriminate the
legitimate exception, where the lint should live and how it should be wired, and whether any new
violation instances exist beyond the ones already migrated.

## Findings

### Codebase Patterns

**The remedy's own history, verbatim.** `git log` for task 589 shows six phases; its completion
summary (`specs/589_test_suite_repo_root_walk_up_depth/summaries/01_test-root-resolution-remedy-summary.md`,
preserved in git history even though the task directory itself has since been archived/renumbered
out of `specs/state.json`) states the Follow-ups section verbatim:

> A `lint-test-root-resolution.sh` closing this class by construction (the shape
> `lint-test-harness-adoption.sh` models) was identified as a worthwhile follow-up during
> planning but intentionally not built here — see the plan's Non-Goals.

and the plan's Non-Goals state the sanctioned-shape carve-out directly:

> Migrating the fixed-depth walks that already sit inside a `git rev-parse`-guarded fallback
> branch. They are the sanctioned shape and are correct as written.

This settles both the lint's name/shape-model and its core discrimination rule without needing
to re-derive either from scratch.

**`lint-test-harness-adoption.sh` as the structural model** (read in full at
`agent-system/extensions/core/scripts/lint/lint-test-harness-adoption.sh`). Its shape, directly
reusable for the new lint:

- Scan scope defined once and shared with `script-inventory.sh`'s own test-file classification:
  a `*.sh` file is in scope when it lives under a `tests/` directory anywhere in its path, OR its
  basename starts with the literal prefix `test-`. The new lint should reuse this exact
  classification (it is already the corpus's agreed boundary for "what counts as a test suite"),
  rather than inventing a second one.
- Root resolution for the *lint script itself*: git-first with a fixed-depth fallback — i.e. the
  lint practices what it polices.
- Detection is line-oriented regex matching (not a shell parser), with an explicitly documented
  `KNOWN LIMITATION` paragraph stating what it cannot catch and why that is an acceptable
  trade-off for a corpus-wide content lint.
- A narrowly-scoped, by-`path:line`, directly-inspected `ALLOWLIST` associative array is the
  mechanism for a confirmed legitimate exception, each entry carrying a one-line justification
  comment — never a blanket exemption, never the default response to a failing run.
- Usage: `lint-X.sh [--verbose] [--help] [path...]` — explicit paths replace the default corpus
  scan (used by the lint's own fixture test, never adding to the default scan).
- Exit codes: 0 clean, 1 violations found, 2 environment/usage error.
- A sibling fixture test (`scripts/tests/test-lint-test-harness-adoption.sh`) exercises both
  polarities (the violating shape fires, both legitimate shapes stay silent) against synthetic
  fixtures in a scratch directory — never against the live tree.

**The exact shape to forbid, confirmed by direct measurement.** From
`agent-system/extensions/core/scripts/tests` (source-store), `cd "$CORE_DIR/../../../.."` (4
levels up from the `scripts/` dir) resolves to the real repository root. From the deployed
`.claude/scripts/tests` (2 levels shallower on disk), the identical 4-level walk resolves to
`/home/benjamin` — one level *above* the repository root entirely. This was reconfirmed directly
in this session (not merely cited from the remedy task) by executing the literal `cd` chains from
both locations.

**The exact shape that is sanctioned**, confirmed present and already in wide use (all four
`test-approve-*.sh` suites, `test-routing-resolution.sh`, `test-double-loading-check.sh`,
`test-lint-test-harness-adoption.sh`, `test-dispatch-metrics.sh`, and the deprecated
`test-roadmap-items-producer.sh` all follow it):

```bash
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"   # fallback only, never reached inside a git tree
fi
```

A second sanctioned variant — a **validated candidate**, used by `run-all.sh`,
`test-task-type-detect.sh`, and `test-common-lib.sh` — computes the fixed-depth path, then
checks it is actually the thing it claims to be (directory exists AND is named `extensions`, or a
known sentinel file such as `core/manifest.json` exists inside it) before accepting it, falling
through to a second, differently-shaped computation otherwise:

```bash
CANDIDATE_EXT_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || true)"
if [ -n "$CANDIDATE_EXT_ROOT" ] && [ -f "$CANDIDATE_EXT_ROOT/core/manifest.json" ]; then
  MODE="source-store"; EXTENSIONS_ROOT="$CANDIDATE_EXT_ROOT"
else
  MODE="deployed"; EXTENSIONS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
```

`test-common-lib.sh` (lines ~601-624) documents, in its own comments, a *previously-uncorrected*
instance of exactly this defect inside itself — "the root was resolved by a fixed `../../..`
walk from SCRIPT_DIR, correct only in the source-store layout and silently landing on the repo
root (over-scanning) when this suite runs from the deployed `.claude/scripts/tests/` copy" — and
its own fix (the validated-candidate idiom above) is the clearest in-repo illustration of the
exact defect-to-fix transformation this lint should mechanically enforce going forward.

**The genuinely-passes-both exception, and why it resists the discriminator above.**
`test-verify-deploy-gate-selection-crash-net.sh:50-51` computes `REPO_ROOT` unconditionally, with
*no* git-first or validated-candidate guard at all:

```bash
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$CORE_DIR/../../../.." && pwd)"
```

Directly re-executing this chain from the deployed location in this session confirms it resolves
to `/home/benjamin` (wrong) exactly as from the crash-net suite's own deployed copy. The suite
still "passes both" because — per its own header comment and the remedy summary's Decisions
section — its sole assertion checks that no registered gate *crashes* when run standalone against
a real-copy fixture; an empty/missing fixture (the consequence of `rsync`-ing from a
wrong/nonexistent `$REPO_ROOT/agent-system/extensions/`) makes every content-dependent gate
legitimately report "no findings" rather than crash, which is still a pass for a suite whose
entire purpose is a crash net, not a findings-correctness check. **This is a property of what the
suite asserts, not of the path arithmetic**, so no purely mechanical (regex/path-shape) rule can
discriminate it from a genuine defect; it needs an allowlist entry, directly inspected and
justified, exactly as `lint-test-harness-adoption.sh`'s own `ALLOWLIST` does for its one
confirmed false positive.

### Newly-Found, Currently-Live Instances (beyond the five+two task 589 already migrated)

Re-running task 589's own "measure every fixed-depth walk-up in a test-suite-classified file,
check for a git-first/validated-candidate guard" method against the current tree (not merely
re-citing task 589's findings) surfaced three further suites still carrying the unconditional
shape today:

1. **`agent-system/extensions/core/scripts/test-state-write-spill-names.sh:74`**
   (`REAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"`, no git-first). This file is NOT
   under a `tests/` directory (it lives directly in `scripts/`) but its basename starts with
   `test-`, so it is in scope under the shared classification. Confirmed by direct execution:
   resolves correctly from the source-store location, resolves to `/home/benjamin` from the
   deployed location (`.claude/scripts/test-state-write-spill-names.sh` exists and is
   byte-identical). The variable feeds a guard — "the real repo `specs/state.json` must be
   untouched by this run, start and end" — that, from the deployed invocation path, checks
   `/home/benjamin/specs/state.json` (nonexistent), finds `real_state_before` empty, and (by the
   surrounding logic, not reproduced destructively here) would report the guard as satisfied
   regardless of whether the real `specs/state.json` was actually touched — i.e. it silently
   stops verifying the one thing it exists to verify, the exact masking hazard the task
   description names.
2. **`agent-system/extensions/core/scripts/tests/test-source-store-path-lib.sh:136`**
   (`REAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"`, no git-first, 5-level). Milder
   than (1): the one use site is guarded by `if [ -f "$REAL_REPO_ROOT/.claude-extensions.json" ]`
   with an explicit `else` branch that emits a visible `common_test_info "...skipped..."` rather
   than silently passing — still the forbidden shape, but self-aware about its own fragility
   rather than silently masking.
3. **`agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh:308,313-314`**
   (`CORE_DIR="$SCRIPT_DIR/.."` then three bare uses of `"$CORE_DIR/../../../.."` /
   `"$CORE_DIR/../../../../specs/..."`, no git-first, no validation of `CORE_DIR` itself). Same
   silent-masking shape as (1): from the deployed path this resolves outside the repo, so
   `git -C "$CORE_DIR/../../../.." status --porcelain -- specs/ 2>/dev/null | grep -q ...` finds
   nothing (git fails quietly on a non-repo path, suppressed by `2>/dev/null`), and the suite
   reports `common_test_pass "no real specs/ state was created or mutated by this probe"` — a
   pass that verifies nothing, for a guard whose entire purpose is catching exactly that leak.

None of these three were in task 589's named five, its one adjacent discovery
(`test-gate-cache-equivalence.sh`, already migrated — confirmed current source now calls
`common_test_repo_root "$SCRIPT_DIR"` directly), or its second sweep discovery
(`test-verify-deploy-gate-selection-crash-net.sh`, confirmed above as the sanctioned exception).
This directly reinforces the task description's own argument for a lint over a hand-assembled
list: a third independent sweep, using the same method, still found instances nobody had named.

### Scope boundary: production scripts carry the same shape too, but are out of this lint's stated scope

`agent-system/extensions/literature/scripts/zotero-setup.sh`, `zotero-read.sh`,
`zotero-attach-chunks.sh`, and two `deprecated/zotero-index-*.sh` files all compute
`PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"` unconditionally — `zotero-chunk.sh`'s own
comment (line 38) even states outright "`../../../..` depth is WRONG here: it assumes this script
always runs from the nested [...]" for a sibling in the same directory. These are production
scripts, not test suites (none live under a `tests/` directory or carry a `test-` prefix), so
they fall outside both this task's literal framing ("invocation-path-dependent repo-root
resolution in **test suites**") and `lint-test-harness-adoption.sh`'s scan-scope precedent this
lint is modeled on. Flagging for the plan to make an explicit scope call rather than silently
including or excluding them: the task's own title says "class closure," and the remedy task
already fixed one production-script instance
(`orchestrate-build-aux-dispatch.sh`, confirmed migrated to the
`common_test_ext_root(common_test_repo_root(...))` candidate-list pattern) as a direct consequence
of its test-suite sweep — so production scripts are demonstrably part of the same underlying
defect class even though the task description's literal scope language is test-suite-only.
Recommendation below treats this as a named, deliberate Non-Goal rather than a silent omission.

### Wiring: gate-registry.data and verify-deploy.sh

`lint-test-harness-adoption.sh` — the structural model this task is asked to follow — is **not**
itself wired into `verify-deploy.sh` or registered in `gate-registry.data` as a gate. It exists
only as a standalone script plus its own fixture-based unit test
(`scripts/tests/test-lint-test-harness-adoption.sh`, classified `unit` in
`scripts/tests/suite-classification.data`). By contrast, several *other* lints under
`scripts/lint/` (`lint-routing-wiring.sh`, `lint-lifecycle-status-var.sh`,
`lint-agent-contracts.sh`, `lint-postflight-boundary.sh`, `lint-anchor-pointer-collapse.sh`,
`lint-contract-compliance.sh`, and the 28 gates total currently in `gate-registry.data`, the
highest numbered being gate 28 / `lint-deliberate-break-residue.sh`) are wired as explicit
inline blocks in `verify-deploy.sh` or as a declarative `gate-registry.data` row (9 tab-separated
fields: `id name invoke dependencies requires_source_store timeout_s cost_class serialized
input_corpus`). This means the dispatch's open question — "whether this is a new standalone lint
script or an assertion inside an existing one, and whether it registers as its own gate or folds
into an existing gate" — has **two live precedents in the corpus itself**, not one: the model
lint is unregistered/standalone, but the broader `lint-*.sh` family is predominantly registered.
`gate-registry.data`'s next free id is 29. `.claude-extensions.json`'s `source_dir` for `core` is
`/home/benjamin/.config/nvim/agent-system/extensions/core`, confirming the edit target the
dispatch names.

## Recommendations

- **Build `lint-test-root-resolution.sh`** under `agent-system/extensions/core/scripts/lint/`,
  directly modeled on `lint-test-harness-adoption.sh`'s structure (scan-scope reuse, line-oriented
  regex detection with a stated `KNOWN LIMITATION`, `--verbose`/`--help`/`[path...]` usage, exit
  0/1/2, a sibling `test-lint-test-root-resolution.sh` fixture test under `scripts/tests/`
  exercising both polarities against synthetic fixtures). This is directly named by the remedy
  task's own Follow-ups entry — no new naming decision needed.
- **Detection rule**: within a file matching the shared test-suite scan scope, flag an assignment
  of the shape `VAR="$(cd "<path-expr containing one or more literal ../ segments>" [2>/dev/null]
  && pwd [|| true])"` (or the `cd "<dir>" && ... pwd` two-statement variant) when that same
  variable's assignment is **not** preceded, in the same conditional chain or an immediately
  prior statement assigning the same variable, by either (a) a `git rev-parse --show-toplevel`
  (or `git -C ... rev-parse --show-toplevel`) attempt, or (b) a validated-candidate check (an
  `if`/`[ -d ... ]`/`[ -f ... ]` test against the computed path before it is accepted as final).
  Concretely: treat it as *sanctioned* only when the fixed-depth `cd` sits inside an `if [[ -z
  "$VAR" ]]; then ... fi` fallback block whose guard variable was just assigned from a
  `git rev-parse` call, OR when the fixed-depth result is itself tested (not merely assigned) before use.
- **Discrimination mechanism for the crash-net exception**: a narrowly-scoped,
  `path:line`-keyed, directly-inspected allowlist array, seeded with exactly one entry —
  `test-verify-deploy-gate-selection-crash-net.sh`'s line 51 — carrying a justification comment
  citing this report's and task 589's own Decisions-section finding (its assertions are
  insensitive to fixture correctness by design). Do not generalize this into a semantic
  "detect crash-net suites" rule; follow `lint-test-harness-adoption.sh`'s own precedent that an
  allowlist entry is a deliberate, reasoned, per-instance act, never a default.
- **Fix the three newly-found live instances** (`test-state-write-spill-names.sh:74`,
  `test-source-store-path-lib.sh:136`, `test-orchestrate-context-growth.sh:308,313-314`) as part
  of landing this lint, migrating each to `common_test_repo_root`/`common_test_ext_root` the same
  way task 589 migrated its six. This is what lets the lint land at zero violations, which the
  dispatch states is the valid completion bar — if these are left unfixed, the lint's first run
  would need its own un-shipped allowlist entries for genuine, not-yet-triaged defects, which is
  a worse outcome than fixing three already-understood instances outright.
- **Wiring decision**: register as gate 29 in `gate-registry.data` (`input_corpus:
  agent-system/extensions/core/scripts/tests/*.sh,agent-system/extensions/*/scripts/tests/*.sh,
  agent-system/extensions/*/scripts/test-*.sh`, `requires_source_store: true`,
  `cost_class: free`, matching the shape of the other content-only lints such as gate 24/26/28),
  and add the corresponding inline `verify-deploy.sh` wiring only if the plan decides gate-
  registry-style declarative registration isn't itself sufficient (several existing lints are
  wired both ways — check `gate_registry_execute`'s own calling convention in
  `lib/gate-registry-lib.sh` before assuming one mechanism suffices). This is a genuine open
  decision the plan should make explicitly rather than defaulting silently to
  "standalone/unregistered" by imitating the model lint's own gap — an unregistered lint has no
  deploy-time enforcement, which undercuts "durable guard" as the task's stated goal.
- **Coordinate with task 584** before editing `gate-registry.data`: that task (not yet started,
  per `specs/state.json`) also declares this file in its `file_scope` for an unrelated change
  (gate 8's `input_corpus` scoping). No line-level collision is expected (584 edits an existing
  row; 601 appends a new one), but re-read the file immediately before editing per the standing
  territory contract, and prefer running after 584 lands if both are dispatched in the same
  cycle.
- **Register the new fixture suite** in `scripts/tests/suite-classification.data` (as `unit`,
  matching `test-lint-test-harness-adoption.sh`'s own entry) and add a cost hint in
  `scripts/tests/suite-cost-hints.txt`, mirroring the existing lint-fixture-suite pairs exactly.

## Decisions

- The lint's name, its structural model, and the core sanctioned-vs-forbidden discriminator are
  not open questions this report leaves for the plan to invent — they are already settled by
  task 589's own completion summary and plan Non-Goals, and this report treats them as fixed
  inputs rather than re-deriving them from first principles.
- Production-script instances of the same shape (the five `zotero-*.sh` scripts) are treated as
  an explicit Non-Goal for this lint's initial scope, consistent with the task description's own
  "test suites" framing, rather than silently folded in or silently ignored.

## Risks & Mitigations

- **Risk**: a purely line-oriented regex lint (the only tractable approach at this corpus's scale,
  per `lint-test-harness-adoption.sh`'s own documented `KNOWN LIMITATION`) cannot see through
  variable indirection or multi-line continuations, and could miss a walk-up shape spread across
  several statements. **Mitigation**: scope the detection to the two concrete AST shapes observed
  in every real instance found (single-line `cd "...$VAR/../.../.." ... pwd`, inline or as a
  two-statement `cd ... ; VAR=$(pwd)` pair), document the limitation explicitly in the lint's own
  header exactly as the model lint does, and accept "the known bad shape is not present" rather
  than "every suite's root resolution is provably safe" as the lint's honest claim.
- **Risk**: landing a new gate (option chosen above) that scans `agent-system/extensions/**`
  broadly could re-trigger gate 8's full-battery-on-any-touch cost problem that task 584 is
  separately addressing. **Mitigation**: scope `input_corpus` narrowly to shell files matching
  the shared test-suite classification only (not `@extensions` broadly), keeping the new gate's
  own footprint small regardless of how 584 resolves gate 8.
- **Risk**: fixing the three newly-found live instances could reveal further masked, currently-
  silent-pass defects underneath them (as task 589's own Phase 6 found a second independent
  defect once the root-cause mask was removed from `test-gate-cache-lib.sh`). **Mitigation**:
  budget for this explicitly in the plan rather than treating "migrate the root computation" as
  guaranteed to be the only change each of the three files needs; re-run each migrated suite from
  both invocation paths and diff the pass/fail tallies, exactly as task 589's own verification
  did.

## Context Extension Recommendations

- **Topic**: shell-script-testing.md (or an equivalent standards file) does not yet document the
  sanctioned-vs-forbidden root-resolution discriminator this report and task 589's plan both
  independently derived (git-first-guarded fallback = sanctioned; validated-candidate-with-
  fallback = sanctioned; unconditional fixed-depth = forbidden). **Gap**: a future suite author
  has no single documented rule to consult before writing a new `REPO_ROOT=...` line, only
  `lib/common.sh`'s own header comments and two prior tasks' worth of git history.
  **Recommendation**: once this task's lint lands, fold its detection rule (in prose) into
  `context/standards/shell-script-testing.md` alongside the existing
  `common_test_repo_root`/`common_test_ext_root` usage guidance, so the rule is discoverable
  without archaeology through task history.

## Appendix

- Search queries / commands used: `grep -rn '\.\./\.\./\.\./\.\.\|\.\./\.\./\.\.'` across
  `agent-system/extensions/`; direct `cd "<path>/../../../.." && pwd` execution from both the
  source-store and deployed locations of every candidate file; `git log --oneline --all | grep -i
  "task 589"`; `git show <sha>:<path>` to recover task 589's archived plan/summary content no
  longer present in the live `specs/` tree.
- Key files read in full or in relevant part: `agent-system/extensions/core/scripts/lint/lint-test-harness-adoption.sh`,
  `agent-system/extensions/core/scripts/lib/common.sh` (lines ~240-330),
  `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection-crash-net.sh`,
  `agent-system/extensions/core/scripts/test-state-write-spill-names.sh`,
  `agent-system/extensions/core/scripts/tests/test-source-store-path-lib.sh`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh`,
  `agent-system/extensions/core/scripts/tests/test-common-lib.sh` (lines ~595-635),
  `agent-system/extensions/core/scripts/tests/run-all.sh` (lines ~335-360),
  `agent-system/extensions/core/scripts/tests/test-task-type-detect.sh`,
  `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` (lines ~130-185),
  `agent-system/extensions/core/scripts/gate-registry.data`.
- References: task 589 (`589_test_suite_repo_root_walk_up_depth`, archived from the live tree but
  recoverable via `git show` on commits `fe51898e9`, `7ac139f6b`, `515a0b8fe`); task 573 (named
  by task 589 as the record-only dependency, not itself investigated here — out of this task's
  scope); task 584 (`gate8_covering_suite_selection`, `not_started`, shares `gate-registry.data`
  in its declared `file_scope`).
