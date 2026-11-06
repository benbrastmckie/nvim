# Implementation Plan: Task #489

- **Task**: 489 - Derive gate-count expectations from the live gate registry
- **Status**: [IMPLEMENTING]
- **Effort**: 6.75 hours
- **Dependencies**: Serialize behind records 328, 435, 448, 418, 414 (shared declared paths; see Risks)
- **Research Inputs**: None (no research artifact; the dispatch description carries the verified defect, the file/line inventory, and the acceptance bar — planned directly from it plus first-hand codebase reads, per planner Stage 1.5)
- **Artifacts**: plans/01_registry-derived-gate-count-expectations.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`verify-deploy.sh` already dispatches gates dynamically (`gate_registry_ids` + `gate${id}_run`),
so registering a gate should be a `gate-registry.data` row plus a function. Five assertions in two
test suites defeat that by writing the live gate count into integers. This plan converts every
count-bearing assertion to read the registry at test time, adds two cross-source guards so the
suites' id set and `verify-deploy.sh`'s own `--only-gate` bound cannot drift apart, and proves the
conversion durable by registering a throwaway gate in a **copied** source store (never in the real
`gate-registry.data`) and showing both suites stay green with zero edits.

Codebase reads during planning found **three further sites of the same defect class** that the
description's "sole remaining place" framing does not cover. These are included (Phase 3) because
the task's stated goal — registering a gate requires no edits to unrelated files — is not met while
they stand:

- `scripts/tests/test-verify-deploy-gate-selection-crash-net.sh:84` — `for n in $(seq 1 23)`. This
  one fails *silently*: the crash net has simply not covered gates 24, 25, 26 since they were
  registered. It under-covers rather than going red, which is why it was absent from the
  five-broken-assertions inventory.
- `scripts/measure-gate-costs.sh:352` — `for _g in $(seq 1 23)`. Production code: the cost model
  that feeds every gate's `timeout_s` has silently never measured gates 24-26.
- Stale prose counts in `lib/gate-registry-lib.sh:4`, `measure-gate-costs.sh:94`,
  `tests/test-gate-cache-equivalence.sh:6`, and both target suites' own headers.

### Research Integration

No research report exists for this round. The dispatch description supplied the defect, the
affected files, and the acceptance bar; planning added first-hand reads of
`scripts/gate-registry.data`, `scripts/lib/gate-registry-lib.sh`,
`scripts/verify-deploy.sh:367-402` and `:2035-2050`, `scripts/lint/lint-gate-registry.sh`,
`scripts/tests/suite-classification.data`, `scripts/tests/suite-cost-hints.txt`, and
`agent-system/extensions/core/manifest.json`. Findings that shaped the phases:

1. `gate_registry_ids` already exists and already sorts ascending; `verify-deploy.sh` derives its
   `--only-gate` bound with an inline max loop over it (with an explicit `23` literal fallback for
   a missing library). That loop is the one derivation to single-source on.
2. `verify-deploy.sh` resolves only `${_VD_SCRIPT_DIR}/gate-registry.data`, `${_VD_SCRIPT_DIR}/lib/*`
   and `${_VD_SCRIPT_DIR}/../..` relative to itself. A fixture store needs only
   `verify-deploy.sh` + `lib/` + `lint/` + `gate-registry.data` copied into a **path-mirrored**
   root (`<root>/agent-system/extensions/core/scripts/`) — no production test seam, no env
   override, no 8.4 MB copy of `tests/`.
3. A throwaway `gate27_run` can be defined by appending it to the **copied**
   `lib/gate-registry-lib.sh`, which `verify-deploy.sh` sources (~line 281) long before the
   dispatch loop (~line 2035). Function resolution is at call time, so the appended body may use
   `say`/`pass`/`gate_selected` from `verify-deploy.sh` itself.
4. `lint-gate-registry.sh` Check E already enforces id uniqueness and contiguity from 1, and suite
   A's case31 is the positive control that the real registry passes that lint. Tests may therefore
   derive the id list directly and need not re-assert contiguity.
5. A new library file requires a `manifest.json` entry (gates 5 and 13 catch a missing one). A new
   *test suite* would additionally require a `tests/suite-classification.data` row — avoided here
   by placing the fixture-gate proof as cases inside the two existing suites rather than as a
   wrapper suite, which also avoids re-paying suite B's ~37 s cost a second time per gate-8 run.
6. `tests/suite-cost-hints.txt` is advisory and mechanically regenerated; no hand edit is needed
   or wanted.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Every gate-count expectation in the gate test corpus is read from `gate-registry.data` at test
  time, via the same `gate_registry_ids` surface `verify-deploy.sh` uses — not from an integer and
  not from a variable initialised to an integer.
- Each converted assertion keeps its original intent and remains non-vacuous, with a paired
  negative control demonstrating it still goes red when it should.
- Two cross-source guards pin the suites' id set to `verify-deploy.sh`'s own notion of it, in both
  directions.
- Registering a gate in a copied fixture store leaves both suites green with zero suite edits,
  demonstrated mechanically and permanently.
- The crash net actually covers every registered gate, and the cost model actually measures every
  registered gate.

**Non-Goals**:
- Adding, removing, or renumbering any real gate; `scripts/gate-registry.data` is **not** modified
  by this task.
- Regenerating `gate-cost-model.csv` or `tests/suite-cost-hints.txt`. Phase 3 makes
  `measure-gate-costs.sh` enumerate the live id set; running the measurement pass that would
  produce rows for gates 24-26 is a separate, expensive job and is deliberately left out.
- Changing `verify-deploy.sh`'s degrade-safe `23` fallback for a missing registry library into a
  refusal. That literal is reachable only when `lib/gate-registry-lib.sh` is absent, where no
  derivation is possible; narrowing it is a behavioural change to a degrade path and belongs to its
  own task. Phase 2 preserves it verbatim and flags it in a comment as degrade-only.
- Introducing a production test seam (an env var selecting an alternate registry file). The
  path-mirrored fixture-store copy achieves the same proof with no production surface.
- Any gate-level parallelism, caching, or selection behaviour change.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A derived expectation becomes self-referential (comparing `gate_registry_ids` to itself) and the assertion silently goes vacuous | H | M | Suite A's case1 derives its expectation by an **independent** reader of the same data file (`awk -F'\t' '$1 ~ /^[0-9]+$/ {print $1}' \| sort -n`), never from the loader under test; every converted assertion gets a paired negative control (Phases 4, 5) |
| Concurrent siblings edit the same files this cycle | H | M | Records 328/435/448 share both declared paths and 418/414 share `gate-registry.data`; serialize (never co-schedule). Re-read each file immediately before editing, stage explicit file lists only, never a directory or glob pathspec |
| The fixture-store copy diverges from a real store and a gate dies before printing its header, breaking the derived header-set guard | M | M | Copy `lib/`, `lint/`, `gate-registry.data` and `verify-deploy.sh` into a path-mirrored root so `${_VD_SCRIPT_DIR}/../..` resolves sanely; the no-flag fixture run targets `FIXTURE_CHEAP`, against which the real store already prints every header today (suite B case (d)) |
| Changing `verify-deploy.sh`'s arg-parse bound regresses `--only-gate`'s error text, which two suites grep verbatim | M | L | Phase 2 keeps both error strings byte-identical and is verified by the resolver-selected suite set before Phase 4/5 touch any assertion |
| The crash net's new coverage of gates 24-26 inflates suite runtime | L | H | All three are `cost_class free`, `timeout_s 30`; the suite's 148.6 s is dominated by one real gate-3 run (~114.7 s), so the increase is a few seconds, not proportional. Recorded, not mitigated away |
| `measure-gate-costs.sh` gains a guarded source and could abort if the library is missing | M | L | Use `verify-deploy.sh`'s exact degrade-safe idiom (`[ -f ] && .` plus a `declare -F \|\| stub`), falling back to `seq 1 23` with a warning rather than exiting |
| A new library file is deployed but unregistered, tripping gate 5/13 | M | M | Phase 1 adds the `manifest.json` entry in the same phase as the file, and its verification runs `--only-gate 5,13` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 1, 2 |
| 4 | 6 | 1, 4, 5 |
| 5 | 7 | 6 (transitively 1-5) |

Phases within the same wave can execute in parallel.

---

### Phase 1: Registry Max Accessor and Fixture-Store Builder [COMPLETED]

**Goal**: Provide the single derivation surface every later phase reads from, plus the shared
fixture-store builder the Phase 6 proof needs, with no behaviour change to any existing caller.

**Tasks**:
- [x] Add `gate_registry_max_id` to `scripts/lib/gate-registry-lib.sh`: prints the largest loaded
      id, prints nothing when `_GREG_IDS` is empty (never `0`, so a caller can distinguish "no
      registry" from "a registry whose max is 0"), returns 0 in both cases. Follow the file's own
      `gate_registry_ids` style, including the local-variable `unset` hygiene. *(completed:
      verified prints 26 against the real registry, empty/rc=0 with nothing loaded)*
- [x] Create `scripts/lib/gate-store-fixture-lib.sh` exposing
      `gate_store_fixture_build <dest_root> <extra_id> [gate_name]`, which:
      - creates `<dest_root>/agent-system/extensions/core/scripts/` and copies `verify-deploy.sh`,
        `gate-registry.data`, `lib/` and `lint/` into it (not `tests/` — avoids a 4 MB copy and any
        nested-run-all ambiguity);
      - appends one well-formed TAB-separated 9-field row for `<extra_id>`
        (`<id>`, name, `gate<id>_run`, `-`, `false`, `30`, `free`, `false`, `-`);
      - appends a minimal `gate<id>_run` definition to the **copied**
        `lib/gate-registry-lib.sh` whose body is `gate_selected <id>` guarded and calls
        `say "<id>. <name>"`, `CURRENT_GATE="gate<id>"`, `pass "..."`, `say ""` — the exact shape
        `gate16_run` uses;
      - echoes the absolute path of the copied `verify-deploy.sh`. *(completed: also inserts a
        second, byte-identical copy of the function block into the copied verify-deploy.sh itself,
        immediately before the dispatch loop -- discovered necessary because lint-gate-registry.sh's
        Check A greps verify-deploy.sh's text only, never a sourced lib; verified end-to-end)*
- [x] Document in that file's header why the copy is path-mirrored (so
      `${_VD_SCRIPT_DIR}/../..` resolves to a plausible extensions root) and why the throwaway
      function is appended to the copied library rather than to the copied `verify-deploy.sh`
      (sourced before dispatch; call-time resolution of `say`/`pass`). *(completed)*
- [x] Add `"scripts/lib/gate-store-fixture-lib.sh"` to `agent-system/extensions/core/manifest.json`
      in its correct alphabetical position within the same list that already carries
      `scripts/lib/gate-registry-lib.sh`. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: Both files are purely additive with no existing caller, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-registry-resolution.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh`
(the resolver-selected set for `gate-registry-lib.sh`) plus
`bash .claude/scripts/verify-deploy.sh --only-gate 5,13,22 .` covers the library edit, the new
manifest row, and shellcheck.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` - add `gate_registry_max_id`
- `agent-system/extensions/core/scripts/lib/gate-store-fixture-lib.sh` - new file
- `agent-system/extensions/core/manifest.json` - register the new library file

**Verification**:
- `gate_registry_load scripts/gate-registry.data; gate_registry_max_id` prints `26`; with no
  registry loaded it prints empty and returns 0.
- `gate_store_fixture_build "$tmp" 27 'Throwaway fixture gate'` produces a tree whose copied
  `verify-deploy.sh --only-gate 27 <any-target>` is **accepted** (not the out-of-range error) and
  prints a `^27\. ` header, and whose `--only-gate 28` is refused with exit 2.
- The fixture registry passes `bash scripts/lint/lint-gate-registry.sh <fixture>/…/gate-registry.data`
  cleanly (ids contiguous 1..27, nine fields, grammar-conformant corpus).
- `run-all.sh --only test-gate-registry-resolution.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh`
  green; `verify-deploy.sh --only-gate 5,13,22 .` green.

---

### Phase 2: Single-Source `verify-deploy.sh`'s `--only-gate` Bound [COMPLETED]

**Goal**: Make `verify-deploy.sh`'s bound and the suites' expectation read the same function, so
Phase 4's guard pins a shared derivation rather than two coincidentally-equal loops.

**Tasks**:
- [x] Replace the inline max loop at `verify-deploy.sh:381-384` with a call to
      `gate_registry_max_id`, keeping the `_only_gate_max_id` variable name and the surrounding
      control flow. *(completed)*
- [x] Add the degrade-safe stub line (`declare -F gate_registry_max_id >/dev/null 2>&1 || gate_registry_max_id() { :; }`)
      beside the existing `gate_registry_ids`/`gate_registry_load`/`gate_registry_field` stubs so a
      missing library still degrades rather than aborting. *(completed)*
- [x] Preserve the `[ "$_only_gate_max_id" -eq 0 ] && _only_gate_max_id=23` fallback verbatim and
      extend its comment to state that this literal is reachable **only** when
      `lib/gate-registry-lib.sh` is absent, where no derivation is possible, and is therefore not a
      count that drifts with the registry. *(completed)*
- [x] Leave both error message strings byte-identical (`ERROR: --only-gate: invalid gate id '%s'
      (must be a number 1-%s)` and `… is out of range (must be 1-%s)`), and leave the `unset` line
      covering the loop variable consistent with whatever variables survive. *(completed: verified
      via git diff that no hunk touches either ERROR: --only-gate line; unset now drops the
      retired loop variable `_vd_known_gate_id`)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: The edit changes `verify-deploy.sh`'s `--only-gate` arg-parse contract,
whose call sites span multiple suites, so the covering check is the 28-suite resolver-selected set
for `verify-deploy.sh` (`suite_selection_select agent-system/extensions/core/scripts/verify-deploy.sh`)
run via `run-all.sh --only`, which no cheaper single-module lint reaches.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - derive the bound from
  `gate_registry_max_id`

**Verification**:
- `verify-deploy.sh --only-gate 26 <repo-root>` accepted and selects gate 26;
  `--only-gate 27` refused with exit 2 and the exact text
  `ERROR: --only-gate: gate id '27' is out of range (must be 1-26)`;
  `--only-gate abc` refused with the exact invalid-id text.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only "$(source agent-system/extensions/core/scripts/lib/suite-selection-lib.sh; suite_selection_select agent-system/extensions/core/scripts/verify-deploy.sh | paste -sd,)"`
  green (28 suites, pre-existing state of both target suites preserved — they are not edited yet).
- `git diff` on the error-message lines is empty.

---

### Phase 3: Collateral Derivation — Crash Net, Cost Model, Stale Prose [COMPLETED]

**Goal**: Close the three same-class sites found during planning, so the crash net covers every
registered gate and the cost model measures every registered gate.

**Tasks**:
- [x] `tests/test-verify-deploy-gate-selection-crash-net.sh`: source
      `../lib/gate-registry-lib.sh`, `gate_registry_load "$CORE_DIR/gate-registry.data"`, and
      replace `for n in $(seq 1 23)` with iteration over `$(gate_registry_ids)`. Make case (b)'s
      pass message interpolate the derived count instead of stating `23`. *(completed: verified
      green, pass message now reads "all 27 registered gates (1 2 ... 27)" -- the live set, which
      now includes sibling task 418's real gate 27)*
- [x] Record in that suite's header that gates 24-26 were **not** covered before this change (a
      silent under-coverage, not a red failure) and that the id set is now registry-derived.
      *(completed)*
- [x] `measure-gate-costs.sh`: add the degrade-safe guarded source of `lib/gate-registry-lib.sh`
      (same idiom as `verify-deploy.sh`), `gate_registry_load`, and fill the default `GATE_LIST`
      from `gate_registry_ids`; keep `seq 1 23` only as the missing-library fallback with a warning
      to stderr. Leave the explicit `--gate` path untouched. *(completed: verified default
      GATE_LIST derives to 1..27 live; `--gate 24 --runs 2` explicit path still works unmodified)*
- [x] Update the three stale prose counts: `lib/gate-registry-lib.sh:4`,
      `measure-gate-costs.sh:94`, `tests/test-gate-cache-equivalence.sh:6` — make each count-free
      ("the registered gate set") rather than restating a number that will drift. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: Each touched file maps to its own covering suite, so
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-gate-selection-crash-net.sh,test-measure-gate-costs.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh`
plus `verify-deploy.sh --only-gate 22 .` (shellcheck) covers the whole edit.

**Scope Hypothesis**: Planning-time `grep -rn 'seq 1 2[0-9]\|all 2[0-9] gate\|2[0-9]-gate\|2[0-9] migrated gate'`
over `scripts/` found exactly these four files beyond the two named suites (two assertion sites,
three prose sites). The implementer must re-run that grep plus
`grep -rnE '\b(2[0-9])\b' scripts/tests/test-*gate*.sh` before closing the phase and widen this
phase if a further site exists.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection-crash-net.sh` -
  derive the crash-net id set
- `agent-system/extensions/core/scripts/measure-gate-costs.sh` - derive the default `GATE_LIST`
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` - header prose only
- `agent-system/extensions/core/scripts/tests/test-gate-cache-equivalence.sh` - header prose only

**Verification**:
- The crash net is observed covering ids 1-26 (instrument the loop once, e.g. `echo` the id list,
  confirm `1 … 26`, then remove the instrumentation) and stays green.
- `measure-gate-costs.sh --regen-hints --skip-gate-measure` still behaves as before (no gate
  measurement pass), and a `--gate 24` invocation measures gate 24 — i.e. the derived default list
  reaches ids the literal never did.
- `run-all.sh --only test-verify-deploy-gate-selection-crash-net.sh,test-measure-gate-costs.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh`
  green; `verify-deploy.sh --only-gate 22 .` green.
- Negative control: with `gate-registry.data` temporarily pointed at a copy missing gate 13's row
  (in a scratch fixture, never the real file), the crash net's loop visibly skips 13 — proving the
  loop follows the data rather than a literal.

---

### Phase 4: Convert `test-gate-registry-resolution.sh` and Add the Bound Guard [COMPLETED]

**Goal**: Suite A asserts nothing about gate counts from an integer, and gains the guard that its
id set matches `verify-deploy.sh`'s own reported bound.

**Tasks**:
- [x] Derive, near the top of the suite, `REGISTRY_IDS_EXPECTED` by an **independent** reader of
      the data file: `awk -F'\t' '$1 ~ /^[0-9]+$/ {print $1}' "$REAL_DATA" | sort -n | tr '\n' ' ' | sed 's/ $//'`,
      and `REGISTRY_MAX` as its last element. Comment explicitly that this must not be derived from
      `gate_registry_ids` — the loader is the thing under test and a self-comparison would be
      vacuous. *(completed)*
- [x] case1: compare `gate_registry_ids` against `REGISTRY_IDS_EXPECTED`; make the pass message
      interpolate the derived count and range rather than naming `26`. *(completed: live value is
      now 27, since sibling task 418 registered a real gate 27 mid-dispatch)*
- [x] case14: interpolate the derived count in the pass message (the loop already iterates
      `gate_registry_ids`; only the message states a stale `25`). *(completed)*
- [x] case32: `--only-gate "$REGISTRY_MAX"` is accepted and prints `^${REGISTRY_MAX}\. `.
      *(completed)*
- [x] case33: `--only-gate "$((REGISTRY_MAX + 1))"` is refused with exit 2 and the out-of-range
      message naming that same id. *(completed)*
- [x] **Guard G1 (new case)**: parse the bound out of `verify-deploy.sh`'s own out-of-range message
      (`must be 1-N`) from the case33 invocation and assert `N == REGISTRY_MAX`. This pins
      `verify-deploy.sh`'s notion of the id set to the suite's, catching a reinstated literal on
      either side. *(completed: verified red when a literal 26 was temporarily reinstated in
      verify-deploy.sh, then reverted with an empty git diff)*
- [x] **Negative controls (new cases)**: a synthetic registry copy with gate 13's row removed must
      make the case1 comparison report a mismatch; a `REGISTRY_MAX`-derived `--only-gate` probe
      built from that same synthetic max must still be refused by the real `verify-deploy.sh`.
      Assert the detection, not the failure, so these cases are green while proving non-vacuity.
      *(completed as case1-NC, two assertions: the id-set mismatch detection, and a probe built
      from the synthetic registry's own derived max+1 still refused by the real verify-deploy.sh)*
- [x] Update the suite header's coverage list and remove its own stale counts. *(completed, plus
      a stale "25 rows" count at case31's comment made count-free during the required re-grep)*

**Timing**: 1.25 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Tier Justification**: Every assertion changed lives in this one suite, so
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-registry-resolution.sh`
is the specific covering check.

**Scope Hypothesis**: Planning-time reading places the count-bearing sites at lines 69, 71, 259,
652-653, 662-663 (case1, case14's message, case32, case33). The implementer must re-grep the suite
for bare `2[0-9]` literals before closing the phase and convert any further site found.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - derived
  expectations, G1 guard, negative controls

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` exits 0 with
  every case PASS and no `[INFO] skipped` for the new cases.
- `grep -nE '\b2[0-9]\b' tests/test-gate-registry-resolution.sh` returns no assertion-bearing hit
  (case numbering and genuinely unrelated numerals excepted, each one inspected).
- Non-vacuity demonstrated per assertion: temporarily break `gate_registry_ids`'s sort, then
  case1 goes red; temporarily reinstate a literal `26` bound in a scratch copy of
  `verify-deploy.sh`, then G1 goes red once the fixture max differs. Both reversions confirmed by
  `git diff` being empty afterwards.
- `verify-deploy.sh --only-gate 22 .` green (shellcheck on the edited suite).

---

### Phase 5: Convert `test-verify-deploy-gate-selection.sh` and Add the Header-Set Guard [COMPLETED]

**Goal**: Suite B's out-of-range probe and full-battery enumeration follow the registry, and its
case (d) becomes a two-directional set-equality guard against `verify-deploy.sh`'s own output.

**Tasks**:
- [x] Source `../lib/gate-registry-lib.sh`, `gate_registry_load "$CORE_DIR/gate-registry.data"`,
      and derive `REGISTRY_IDS` (from `gate_registry_ids`) and `REGISTRY_MAX` (from
      `gate_registry_max_id`) near the fixture setup. *(completed)*
- [x] case (c): replace the literal `27` in `invalid_cases` with `$((REGISTRY_MAX + 1))`, keeping
      `abc`, `0`, `1,abc`, `1,99`. Add a one-line assertion that `REGISTRY_MAX -lt 99` so the
      `1,99` probe cannot silently become in-range; it fails loudly if the registry ever reaches
      99. *(completed)*
- [x] case (c)'s `--findings --only-gate 99` sub-case: keep `99` but let the same `-lt 99`
      assertion protect it, with a comment naming the dependency. *(completed)*
- [x] **Guard G2** — case (d) becomes set equality, not one-directional coverage: collect the
      header ids a no-flag run prints (`grep -oE '^[0-9]+\. ' | tr -d '. '`), sort both sides
      numerically, and assert the printed set equals `REGISTRY_IDS` exactly. Report missing **and**
      extra ids separately in the failure detail, so drift in either direction is named.
      *(completed as a reusable `noflag_header_set_check` function, so Phase 6's fixture case can
      invoke the identical comparison logic)*
- [x] Make case (a)'s and case (d)'s pass messages interpolate the derived count. *(case (d)/G2's
      pass message now interpolates the live count; case (a) has no count to interpolate -- it
      names a single fixed gate id (20), not a total, so left as-is)*
- [x] Update the suite header: replace "full 23-gate battery", "all 23 gates", "all 23 gate
      headers" and the per-fixture SKIP lists' counts with count-free phrasing referring to the
      registered gate set. *(completed; the per-fixture SKIP id ranges themselves, e.g.
      "gates 3/5-13/15/17-20", name specific gate ids being skipped, not a total count, so left
      unchanged)*

**Timing**: 1.0 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Tier Justification**: Every assertion changed lives in this one suite, so
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-gate-selection.sh`
is the specific covering check.

**Scope Hypothesis**: Planning-time reading places the count-bearing sites at lines 142 (the `27`
probe) and 174 (`seq 1 26`), with stale prose at lines 4, 25, 30, 34. The implementer must re-grep
the suite for bare `2[0-9]` literals before closing the phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` - derived probe
  and enumeration, G2 set-equality guard

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` exits 0,
  all cases PASS.
- Non-vacuity, case (c): the derived probe id is confirmed to be exactly `REGISTRY_MAX + 1` by
  echoing it once during a scratch run, and the case still reports exit 2 with a named error for
  it; a deliberately in-range id (`REGISTRY_MAX`) inserted into `invalid_cases` in a scratch copy
  makes case (c) go red, proving the list is not accepted vacuously.
- Non-vacuity, case (d)/G2: removing one id from `REGISTRY_IDS` in a scratch copy makes G2 report
  an *extra* printed id; adding a phantom id makes it report a *missing* one. Both directions
  observed red, then reverted with an empty `git diff`.
- `verify-deploy.sh --only-gate 22 .` green.

---

### Phase 6: Throwaway-Gate Fixture Proof in Both Suites [COMPLETED]

**Goal**: Prove mechanically and permanently that registering a gate requires no suite edits —
the acceptance bar — without ever touching the real `gate-registry.data`.

**Tasks**:
- [x] Both suites source `../lib/gate-store-fixture-lib.sh` and build a fixture store under their
      existing `WORKDIR` (so `common_test_workdir_init`'s trap cleans it up) via
      `gate_store_fixture_build "$WORKDIR/fixture-store" 27 'Throwaway fixture gate'`.
      *(completed with the extra id DERIVED as `$((REGISTRY_MAX + 1))` rather than the bare
      literal `27` the plan's prose assumed -- the real registry's live max had already moved to
      27 by this point in the dispatch, so the fixture's extra id is 28)*
- [x] Suite A, new cases: against the fixture store's `verify-deploy.sh`, (i) the
      independently-derived fixture max is `27`; (ii) `--only-gate 27` is **accepted** and prints
      `^27\. `; (iii) `--only-gate 28` is refused with `must be 1-27`; (iv) G1 applied to the
      fixture store reports a bound of `27`. Assert the real registry is untouched
      (`grep -c '^27\t' scripts/gate-registry.data` is 0). *(completed as case35/35b/36/37/38/39,
      with every literal "27"/"28" replaced by the derived FIXTURE_EXTRA_ID/FIXTURE_ONE_PAST;
      found and fixed a bug while implementing: the fixture case initially passed
      `$WORKDIR/fixture-store` as TARGET, but verify-deploy.sh requires TARGET to already hold a
      deployed .claude/ tree before it reaches gate dispatch at all -- the fixture builder does
      not create one. Fixed by passing `$REPO_ROOT` as TARGET instead, matching Phase 1's own
      manual verification, since `--only-gate <id>` only needs the fixture's OWN
      self-relative-resolved verify-deploy.sh/lib/data, not TARGET itself, to have the fixture
      shape)*
- [x] Suite B, new case: a no-flag `--skip-slow` run of the fixture store's `verify-deploy.sh`
      against `FIXTURE_CHEAP` prints a header for every fixture-registry id including `27`, under
      the same set-equality comparison G2 uses — i.e. case (d)'s logic, re-run against a registry
      with one more gate, with no edit to the assertion itself. *(completed as case (s))*
- [x] Factor each suite's comparison into a small local function so the fixture case and the real
      case invoke identical logic; a divergent second copy would defeat the proof. *(completed:
      `ids_match_check` in Suite A, `noflag_header_set_check` in Suite B -- both defined once,
      called by both the real-registry case and the fixture case)*
- [x] State in both suite headers that these cases are the durable answer to "adding a gate must
      not require editing this file", and that the fixture store is a path-mirrored copy, never the
      real store. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 4, 5

**Verification Tier**: interface

**Tier Justification**: These cases exercise `verify-deploy.sh`'s registry-dispatch and arg-parse
paths through a copied store — a cross-file surface neither suite's own single-module run covers —
so the covering check is `run-all.sh --only test-gate-registry-resolution.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-gate-selection-crash-net.sh,test-lint-unit-integration-boundary.sh`
plus `verify-deploy.sh --only-gate 5,13,22 .`.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - fixture-gate cases
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` - fixture-gate case

**Verification**:
- Both suites exit 0 with the new cases PASS, and `git diff` shows the real
  `scripts/gate-registry.data` unmodified.
- The acceptance bar, demonstrated directly: with the fixture store carrying gate 27, **neither**
  suite required an edit to its assertions between the real-registry cases and the fixture cases —
  the same comparison function serves both, confirmed by reading the diff.
- `test-lint-unit-integration-boundary.sh` green (both suites remain correctly classified
  `integration`; no classification-data change is needed since no new suite file is added).
- Runtime delta recorded for both suites (expected: a few seconds each — the fixture store copies
  ~1.3 MB and adds 2-3 cheap `verify-deploy.sh` invocations); if either suite's wall clock grows by
  more than ~15 s, record an issue via `issue-record.sh` with class `test-fixture-drift`.

---

### Phase 7: Full Gate Battery and Redeploy [NOT STARTED]

**Goal**: Land the work with the complete gate set green and the deployed tree regenerated from the
source store.

**Tasks**:
- [ ] Re-read every file in this task's `file_scope` immediately before the final commit (sibling
      tasks are live on this working tree this cycle) and confirm no foreign hunk is staged.
- [ ] Run the complete gate set: `bash agent-system/extensions/core/scripts/verify-deploy.sh <repo-root>`
      (full battery, gate 8 included, no `--skip-slow`, no `--only-gate`).
- [ ] Redeploy via `deploy-headless.sh` using the bounded-wait idiom (`timeout 540`, Bash tool
      timeout `600000`) and confirm `RESULT=landed_verify_clean`.
- [ ] Confirm the deployed `.claude/scripts/lib/gate-store-fixture-lib.sh` exists post-deploy (the
      manifest row from Phase 1 took effect) and that no orphan is reported.
- [ ] Record the phase's issues/wins via `issue-record.sh`, including the discovery that the
      description's "sole remaining place" framing missed three further sites (class
      `test-fixture-drift`).

**Timing**: 1.0 hours

**Depends on**: 6

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree
- No source-store file is edited in this phase

**Verification**:
- `verify-deploy.sh <repo-root>` reports PASS with a non-zero check count and no FAIL/WARN
  attributable to this task's files.
- `deploy-headless.sh` reaches `RESULT=landed_verify_clean` within the bounded wait.
- Gate 13 (orphan detection) and gate 5 (manifest parity + content-hash equality) both clean,
  proving the new library file is registered and deployed.

## Testing & Validation

- [ ] `gate_registry_max_id` returns the live max from the real registry and empty with nothing
      loaded.
- [ ] `gate_store_fixture_build` yields a store whose `verify-deploy.sh` accepts the extra gate id,
      refuses one past it, and prints the extra gate's header.
- [ ] No gate-count integer survives in any assertion across
      `test-gate-registry-resolution.sh`, `test-verify-deploy-gate-selection.sh`,
      `test-verify-deploy-gate-selection-crash-net.sh`, or `measure-gate-costs.sh`'s default
      `GATE_LIST`.
- [ ] Every converted assertion has a demonstrated red state (negative control in-suite, or a
      recorded scratch-copy demonstration with an empty `git diff` afterwards).
- [ ] G1: `verify-deploy.sh`'s reported `--only-gate` bound equals the registry-derived max.
- [ ] G2: the no-flag header id set equals the registry-derived id set exactly, in both directions.
- [ ] Both suites green against a fixture store carrying a throwaway gate, with zero assertion
      edits between the real-registry and fixture cases.
- [ ] The crash net covers every registered id (observed, not assumed).
- [ ] Full `verify-deploy.sh` battery green; `deploy-headless.sh` reaches
      `RESULT=landed_verify_clean`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` - `gate_registry_max_id` accessor
- `agent-system/extensions/core/scripts/lib/gate-store-fixture-lib.sh` - new fixture-store builder
- `agent-system/extensions/core/manifest.json` - registration of the new library file
- `agent-system/extensions/core/scripts/verify-deploy.sh` - bound single-sourced on the accessor
- `agent-system/extensions/core/scripts/measure-gate-costs.sh` - registry-derived default gate list
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - derived
  expectations, G1 guard, negative controls, fixture-gate cases
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` - derived probe,
  G2 set-equality guard, fixture-gate case
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection-crash-net.sh` -
  registry-derived crash-net id set
- `agent-system/extensions/core/scripts/tests/test-gate-cache-equivalence.sh` - header prose only
- A regenerated deployed `.claude/` tree (Phase 7)
- Issue-log entries in `specs/489_derive_gate_count_expectations_from_registry/issues.jsonl`

## Rollback/Contingency

Every phase is an independent commit, so reverting is `git revert` of the phase commits in reverse
order followed by one `deploy-headless.sh` run to restore the deployed tree. No data file is
mutated: `scripts/gate-registry.data`, `gate-cost-model.csv` and `tests/suite-cost-hints.txt` are
all untouched, so no regeneration is needed on rollback.

Per-phase contingencies:
- If Phase 2's accessor substitution perturbs any `--only-gate` error text, revert that one hunk
  and leave the inline loop; Phases 4-6 still work (they derive independently), losing only the
  single-source property, and G1 still pins the two derivations to each other.
- If a gate dies before printing its header under the Phase 6 fixture store, add the missing
  directory to `gate_store_fixture_build`'s copy list (`tests/` last, since it is 4 MB) rather than
  weakening G2's set equality to one-directional coverage.
- If Phase 3's `measure-gate-costs.sh` change proves to interact with the cost-model regeneration
  path, revert that file alone and keep the crash-net conversion; the two are independent, and the
  measure-gate-costs site is explicitly beyond the task's literal two-suite scope.
- Rollback never uses `git-snapshot.sh` in its reverting default mode: sibling tasks are live on
  this working tree this cycle. Use `--no-revert` for a defensive checkpoint before Phase 2 or
  Phase 7 if one is wanted.
