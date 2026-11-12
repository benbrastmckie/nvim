# Implementation Plan: Task #600

- **Task**: 600 - Sapience retrieve cold-start retry
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/600_sapience_retrieve_cold_start_retry/reports/01_sapience-retrieve-cold-start-retry.md
- **Artifacts**: plans/01_sapience-retrieve-cold-start-retry.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`sapience-retrieve.sh` collapses every non-2xx HTTP status into one catch-all `exit 2` arm before
the response body is ever parsed, so a 503 cold-start body carrying `starting: true` and
`retry_after: 15` is indistinguishable from a 401 or a 500. This plan adds exactly one bounded
retry gated on that narrow discriminator, honoring the server's own `retry_after` hint through a
clamp, and leaves the terminal fail-open degrade (exit 2, unchanged diagnostic, caller records
non-fatally and proceeds with an empty `memory_context`) byte-identical. The test harness is
extended first so the new sleep path is stubbed and assertable before the production change
lands; documentation and a redeploy close the task.

### Premise Re-Validation (Carried-Figure Discipline)

Each of the five extracted trigger-class lines from the dispatch description was checked against
the prior research report and against live files before this plan was built:

1. **Source store is the edit target** (`agent-system/extensions/sapience/**`) — CONFIRMED live:
   `.claude-extensions.json` resolves `.extensions.sapience.source_dir` to
   `/home/benjamin/.config/nvim/agent-system/extensions/sapience`, so the source store is local
   to this repository and the task is correctly sited here.
2. **Root cause in `sapience-retrieve.sh`** — CONFIRMED by direct read, with line numbers moved
   exactly as the description warned: the single `curl -sS --connect-timeout 3 --max-time 8 ...
   -w $'\n%{http_code}'` call is at line 124; the status/body split at lines 134-135; the
   `case "$http_status" in 2??) ... *) ... exit 2 ;; esac` dispatch at lines 137-145, with the
   `genuine failure -- HTTP ${http_status}` diagnostic at line 142. The body-excerpt rationale
   quoted in the description appears verbatim in the script header at lines 22-25. The
   JSON-validity check is at line 147, i.e. architecturally downstream of the status `case` —
   confirming the `starting`/`retry_after` fields are unreachable today.
3. **Caller is Stage 3.5's `memory_context` block, needs no change** — CONFIRMED by direct read
   of `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` lines 351-379: two
   invocation forms both capture `memory_exit`, `exit 2` is mirrored through `issue-record.sh`
   with `--class "infrastructure/transport unavailable"` (line 367-372), and line 378 clears
   `memory_context` on any non-zero exit. The block treats the script as one opaque exit-code
   contract, so a retry hidden inside the script is transparent to it. No numeric wall-clock
   budget for this call exists in that file.
4. **Fail-open degrade must remain the terminal behavior** — this is a requirement rather than a
   figure; it is preserved by construction (Phase 2 keeps the catch-all arm's text and exit code
   untouched and routes the retry's second failure into that same arm) and asserted by Phase 3.
5. **`test-sapience-capture.sh` as the test-siting precedent** — CONFIRMED live: the file exists
   at `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` with 4 cases, a
   `build_scratch` helper, and a PATH-shadowing `curl` stub dispatched by
   `CURL_STUB_CODE`/`CURL_STUB_BODY`/`CURL_STUB_EXIT`. The stub is single-shot, as research
   reported. It is registered in `suite-classification.data:182` as a `unit` suite and in
   `manifest.json`'s `provides.scripts` array, so no registration change is needed.
6. **#519 has no `file_scope` overlap** — CONFIRMED live from `specs/state.json`: #519's scope is
   `orchestrate-cycle-postflight.sh`, its test, `planner-agent.md`, and `handoff-schema.md`;
   this task's is the three sapience paths. No overlap, no serializing edge required. The same
   check against all six concurrent siblings named in this dispatch's Territory block finds no
   shared path either.

### Research Integration

The research report's findings are adopted in full and drive three plan-level decisions. (a) All 11
cited occurrences across two sessions four hours apart carry byte-identical bodies with
`retry_after: 15, db_mb: 0`, which is the evidentiary basis for the 15s default rather than a
round-number guess. (b) The retry must be gated on `503 AND valid JSON AND .starting == true`,
not on any 503, because a plain upstream-unavailable 503 is a genuine failure the ask forbids
retrying. (c) The existing curl stub cannot represent a two-response sequence, so the harness
needs a small additive extension — which this plan sequences *first*, for a reason research did
not surface (see Decisions).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- One bounded retry inside `sapience-retrieve.sh`, gated on the narrow cold-start signal only
  (503 + parseable JSON + `.starting == true`).
- Honor the server's `retry_after` hint through a total clamp (no hardcoded constant delay), with
  a stated, capped worst-case added wall clock.
- Preserve the terminal fail-open degrade exactly: same exit 2, same diagnostic text, same
  caller behavior.
- Four new test cases driving the cold-start path with no live vault, plus an assertion on the
  actual slept duration.
- Document the retry contract and its cap at the source-store path for `per-repo-scoping.md`.

**Non-Goals**:
- Changing the degrade posture. Fail-open retrieval is settled; this plan does not reopen it.
- Any unbounded/uncapped retry loop, more than one retry, or background/async retrieval.
- `sapience-remember.sh` (its own non-zero exits are already mirrored at its call site).
- `orchestrate-build-dispatch.sh` — confirmed unnecessary in Premise Re-Validation item 3. No
  phase below touches it.
- Retrying a 4xx, a non-JSON body, or a curl transport error.
- Adding an env-override surface for the new constants (see Decisions).

## Decisions

- **Clamp rule, stated once and totally.** Extract `retry_after` with `jq -r '.retry_after //
  empty'`. If it does not match `^[0-9]+$` (missing, `null`, non-numeric, negative), use the
  default `15`. Then clamp the result into `[1, 20]`. This makes `0` -> `1`, `9999` -> `20`,
  `"soon"`/absent -> `15`, and `15` -> `15` unchanged. Every input is covered; there is no
  undefined case.
- **Total wait cap and its basis.** Worst case for the cold-start path becomes
  `8s (first curl --max-time) + 20s (clamp ceiling) + 8s (second curl --max-time) = 36s`, versus
  the `8s` the surrounding dispatch build already tolerates today on this call. The ceiling is
  set at 20s rather than higher because the only measured value is 15s (11-for-11 occurrences,
  two independent sessions), so 20s leaves headroom for a slower boot while keeping the added
  cost inside the same order of magnitude as the existing tolerance. Exactly one retry, because
  no cited occurrence shows a second 503 after a 15s wait — there is no observed case that would
  justify a second retry's cost.
- **Fixed constants, not env-overridable.** Research left this choice open, naming both
  precedents (`TOKEN_BUDGET`/`MAX_ENTRIES` fixed in this same file; `task-lock.sh`'s
  env-overridable style). This plan picks **fixed**, declared in the existing `# --- Constants
  ---` block and documented in the header `Constants:` list, for internal consistency with the
  file's two existing constants and to avoid adding an env surface no caller asked for.
- **Testability through a PATH-shadowed `sleep`, not a test-only hook in production code.**
  `sleep` is an external binary (`type -t sleep` -> `file`), and the harness already prepends a
  scratch stub directory to `PATH` for `curl`. Adding a `sleep` stub there that records its
  argument and returns instantly gives both fast tests and a direct assertion on the honored
  delay, with zero test-only affordance inside `sapience-retrieve.sh`. The production script
  must therefore call bare `sleep`, never an absolute path or `command sleep`.
- **Harness first, production change second.** Under the new code the existing Case 1 (a 503
  with `starting: true` against the single-shot stub) still exits 2 and still passes — but it
  would first perform a real 15s sleep. Extending the harness before the script change keeps the
  suite fast at every point in the sequence and means no phase ever observes a red or
  artificially slow suite.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future cold-start body reports a `retry_after` far outside the observed 15s | M | L | The 20s ceiling bounds one dispatch's added build time regardless of the server's claim; the terminal fail-open degrade is unchanged, so a slow boot degrades to an empty `memory_context` rather than stalling |
| A non-cold-start 503 carries an unrelated truthy `starting` field | L | L | Gate on `.starting == true` as a strict boolean via `jq -e`, never a truthy string, and keep the retry single-shot — a false positive costs at most one clamped sleep plus one <=8s request |
| The additive stub extension regresses the four already-passing cases | M | L | Phase 1 is additive only (new env vars with a documented single-response fallback); its verification is that all four existing cases pass unmodified |
| Control-flow restructuring accidentally alters the non-retry diagnostics | M | L | The catch-all arm's text and exit code are left byte-identical and reached from exactly one place; Phase 3 asserts the 4xx, non-JSON, and transport-error paths explicitly |
| `sleep` called via an absolute path would defeat the stub | M | L | Phase 2's verification includes grepping the changed hunk to confirm a bare `sleep` invocation; the fallback, if ever needed, is to make the clamp constants env-overridable after all |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Extend the test harness stubs (additive, no new assertions) [COMPLETED]

**Goal**: Give `test-sapience-capture.sh` the ability to represent a two-response `curl` sequence
and an instant, recorded `sleep`, without changing any existing case's behavior.

**Tasks**:
- [x] Re-read `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh`
      immediately before editing (concurrent siblings are dispatched this same cycle). *(completed)*
- [x] Extend `build_curl_stub`'s inline stub to keep a call counter in a file inside the stub
      directory (incremented on every invocation) and to select its response by call index:
      prefer `CURL_STUB_CODE_1`/`CURL_STUB_BODY_1`/`CURL_STUB_EXIT_1` for the first call and
      `CURL_STUB_CODE_2`/`CURL_STUB_BODY_2`/`CURL_STUB_EXIT_2` for the second and beyond, each
      falling back to the existing unsuffixed `CURL_STUB_CODE`/`CURL_STUB_BODY`/`CURL_STUB_EXIT`
      and then to the current defaults. This keeps every existing unsuffixed invocation
      byte-identical in behavior. *(completed)*
- [x] Add a `build_sleep_stub`-style companion (or extend `build_curl_stub` to also write a
      `sleep` executable into the same directory) that appends each requested duration to a
      recorder file in that directory and exits 0 immediately. *(completed)*
- [x] Add two small helpers for reading back the recorded state: the `curl` call count and the
      recorded sleep durations, so later cases assert rather than infer. *(completed)*
- [x] Document the stub's dispatch contract in the file's header comment block (the suffixed
      vars, the fallback chain, the counter and recorder files). *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-sapience-capture.sh`
is the sole suite `suite_selection_select` returns for
`agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh`, and this phase edits
only that file.

**Scope Hypothesis**: this phase asserts the harness has exactly four existing cases, all
single-call, and that the extension is purely additive. The implementer confirms it by re-reading
the file and by observing the suite report the same passed-count before and after the edit.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` - sequenced `curl`
  stub responses, a recording `sleep` stub, readback helpers, header documentation

**Verification**:
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-capture.sh` passes with the same
  number of passing assertions as before the edit and zero failures.
- Re-reading the diff confirms no existing case's env vars or assertions were changed.

---

### Phase 2: Implement the bounded cold-start retry in `sapience-retrieve.sh` [COMPLETED]

**Goal**: Issue exactly one retry when, and only when, the first response is a 503 whose body
parses as JSON with `.starting == true`, sleeping a clamped `retry_after`, with every other path
and the terminal degrade unchanged.

**Tasks**:
- [x] Re-read `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` immediately before
      editing and re-derive the current line numbers (the request at ~124, the status `case` at
      ~137-145). *(completed)*
- [x] Add three fixed constants to the existing `# --- Constants ---` block:
      `RETRY_DELAY_DEFAULT=15`, `RETRY_DELAY_MIN=1`, `RETRY_DELAY_MAX=20`, with a short comment
      recording that 15 is the measured `retry_after` value this vault reports during cold start,
      not an arbitrary default. *(completed)*
- [x] Extract the request issuance (the `mktemp` scratch-stderr file, the single `curl` call, the
      stderr readback and cleanup) into a function that sets `response_raw`, `curl_exit`, and
      `curl_stderr`, so it can be invoked a second time without duplicating the call. *(completed)*
- [x] Keep the `curl_exit -ne 0` transport-failure branch exactly as it is today: immediate
      `exit 2` with the unchanged diagnostic, never retried. *(completed)*
- [x] After the first status/body split, evaluate the cold-start predicate: `http_status` is
      `503` AND `$response` is non-empty AND `echo "$response" | jq -e . >/dev/null 2>&1`
      succeeds AND `echo "$response" | jq -e '.starting == true' >/dev/null 2>&1` succeeds. *(completed)*
- [x] When the predicate holds: compute the delay per the clamp rule in Decisions, emit one
      short informational line to stderr naming the status, the honored delay, and that this is
      a single bounded retry; call bare `sleep "$delay"`; re-invoke the request function; re-apply
      the transport-error branch and the status/body split to the second response. *(completed)*
- [x] Leave the `case "$http_status" in 2??) ... *) ... exit 2 ;; esac` arm, its diagnostic text,
      and the downstream non-JSON `exit 2` check untouched, and ensure both the no-retry path and
      the post-retry path fall through to that same single site. *(completed)*
- [x] Update the script's header comment block: add the three constants to the `Constants:` list
      and add a sentence stating the retry condition, the clamp, the one-attempt budget, the
      worst-case added wall clock, and that the terminal degrade is unchanged. State the current
      design only (no "previously"/"no longer" framing). *(completed)*
- [x] Confirm `sleep` is invoked bare (`grep -n 'sleep' ` on the file shows no absolute path and
      no `command sleep`). *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only
test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-sapience-capture.sh`
is exactly what `suite_selection_select` returns for
`agent-system/extensions/sapience/scripts/sapience-retrieve.sh`, and this phase edits only that
file.

**Scope Hypothesis**: this phase asserts the script contains exactly one `curl` invocation and
exactly one catch-all non-2xx `exit 2` arm. The implementer confirms both by `grep -c 'curl -sS'`
and by reading the `case` block before restructuring; if a second request site exists, stop and
report rather than refactoring more widely.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` - retry constants, request
  issuance extracted to a reusable function, cold-start predicate and single bounded retry,
  header documentation

**Verification**:
- The four-suite `--only` run above passes with zero failures. Existing Case 1 still reports
  exit 2 with `503` and the body excerpt on stderr, and now completes in well under a second
  because Phase 1's `sleep` stub is in place.
- `bash -n` on the changed script parses clean, and `shellcheck` reports no new findings.
- Reading the diff confirms the catch-all arm's text and exit code are byte-identical.

---

### Phase 3: Add the four required cold-start test cases [NOT STARTED]

**Goal**: Drive the cold-start path with no live vault and assert each of the four behaviors the
dispatch's VERIFICATION section names, plus the honored delay.

**Tasks**:
- [ ] Re-read the harness file immediately before editing.
- [ ] Case: first call 503 + `{"starting": true, "retry_after": 15, ...}`, second call 200 with
      one real hit. Assert exit 0, a populated `<memory-context>` envelope on stdout, the `curl`
      call counter is exactly 2 (exactly one retry attempted, never more), and the recorded sleep
      is exactly one entry of 15.
- [ ] Case: both calls 503 + `starting: true`. Assert exit 2, empty stdout, the unchanged
      diagnostic carrying the status and the body excerpt on stderr, and a `curl` call count of
      exactly 2 (no second retry).
- [ ] Case: a 4xx (e.g. 401) on the first call. Assert exit 2, the unchanged diagnostic, a `curl`
      call count of exactly 1, and an empty sleep recorder — never retried.
- [ ] Case: a 503 with a non-JSON body (e.g. `<html>Service Unavailable</html>`). Assert exit 2,
      the unchanged diagnostic, a `curl` call count of exactly 1, and an empty sleep recorder —
      never retried.
- [ ] Add one clamp case asserting a hint outside the band is clamped rather than honored
      verbatim: first call 503 with `"retry_after": 9999`, second call 200 with a hit; assert the
      recorded sleep is exactly `20`, not `9999`.
- [ ] Extend the header comment block to describe the retry cases alongside the existing
      exit-code-split description.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-sapience-capture.sh`
is the sole suite `suite_selection_select` returns for the one file this phase edits.

**Scope Hypothesis**: this phase asserts five new cases are added (the dispatch's four, plus one
clamp case) and that the four pre-existing cases need no modification. The implementer confirms
the latter by observing the pre-existing assertions still pass unchanged in the same run.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` - five new cases and
  header documentation

**Verification**:
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-capture.sh` passes with zero
  failures and a passed-count increased by the new assertions.
- The suite completes without any multi-second stall, confirming the `sleep` stub is engaged on
  every retry path.

---

### Phase 4: Document the retry contract in `per-repo-scoping.md` [NOT STARTED]

**Goal**: State the settled retry condition, the clamp bounds, the one-attempt budget, the capped
worst-case wait, and the unchanged terminal degrade at the source-store documentation path.

**Tasks**:
- [ ] Re-read `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
      immediately before editing.
- [ ] In the `## The Two Scripts` section's `sapience-retrieve.sh` bullet, amend the clause that
      currently reads that retrieval "never blocks or retries the dispatch on any exit code" so
      it describes the current design accurately: one bounded retry on the narrow cold-start
      signal, and never a block.
- [ ] State the retry contract: the predicate (503 + parseable JSON + `.starting == true`), the
      honored `retry_after` hint, the clamp (`default 15`, band `[1, 20]`), the one-attempt
      budget, the capped worst case (`<=36s` on the cold-start path versus `<=8s` on every other
      path), and that the terminal behavior after the retry is exhausted is the unchanged exit-2
      fail-open degrade with the caller recording non-fatally and proceeding with an empty
      `memory_context`.
- [ ] Note that a 4xx, a non-JSON body, and a curl transport error are explicitly not retried.
- [ ] State the current design only — no task-number references, no "previously"/"no longer"/
      "this replaces" framing (`rules/no-task-references-in-deliverables.md`,
      `rules/no-record-versioning-in-deliverables.md`).

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for
`agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — no suite
covers it — so per plan-format.md's sub-case (b) for a source-store non-`specs/**` markdown edit,
the covering check is `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh
--skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` alongside the `prose` row's diff
read-through.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - retry
  contract, clamp bounds, cap, and the amended never-retries clause

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4
  /home/benjamin/.config/nvim` reports both gates ran (not SKIP) and passed.
- Diff read-through confirms every changed hunk is prose, carries no task-number reference, and
  uses no record-versioning language.
- `grep -n "never blocks or retries"` on the file returns nothing.

---

### Phase 5: Redeploy and run the full gate set [NOT STARTED]

**Goal**: Regenerate the deployed `.claude/` tree from the source store and confirm the complete
repository gate set is green with all of this task's work observable.

**Tasks**:
- [ ] Confirm the working tree holds only this task's own changes among its declared
      `file_scope`, and that no sibling's in-flight edit is being carried (check `git status
      --short` and `git log` before proceeding; if a foreign commit or modification appears,
      STOP and report).
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed tree from the
      source store.
- [ ] Confirm the three deployed mirrors now carry the new content:
      `.claude/scripts/sapience-retrieve.sh`, `.claude/scripts/tests/test-sapience-capture.sh`,
      and `.claude/context/project/sapience/domain/per-repo-scoping.md`.
- [ ] Run the complete gate set and confirm green.
- [ ] Stage and commit only this task's own files with an explicit file list (never a directory
      or glob pathspec), via `.claude/scripts/git-commit-scoped.sh`.

**Timing**: 0.75 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts exactly three source-store files have deployed mirrors
to confirm. The implementer confirms the set by diffing each named source-store path against its
deployed counterpart after the redeploy, and reports any fourth drifted path rather than silently
widening the commit.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` - no further content change;
  deployed mirror regenerated
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` - no further content
  change; deployed mirror regenerated
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - no
  further content change; deployed mirror regenerated

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set, no `--only-gate`, no
  `--skip-slow`) reports every gate green, including Gate 8's full shell-suite battery.
- `bash .claude/scripts/tests/run-all.sh` (unfiltered) passes with zero failures.
- `diff` between each source-store file and its deployed mirror shows no drift.

---

## Testing & Validation

- [ ] A 503 + `starting: true` + `retry_after` first response followed by a 200 yields a
      populated `<memory-context>` and exit 0.
- [ ] Exactly one retry is attempted on the cold-start path — the `curl` call counter reads 2,
      never 3 or more.
- [ ] A second 503 + `starting: true` ends in the unchanged exit-2 degrade with the unchanged
      diagnostic text.
- [ ] A 4xx is never retried (call counter 1, empty sleep recorder).
- [ ] A non-JSON body is never retried (call counter 1, empty sleep recorder).
- [ ] A curl transport error is never retried and keeps its existing diagnostic.
- [ ] A `retry_after` outside `[1, 20]` is clamped, and a missing or non-numeric one falls back
      to 15.
- [ ] The four pre-existing harness cases pass unmodified.
- [ ] The complete gate set and the unfiltered shell-suite battery are green after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` with the bounded cold-start
  retry and its three fixed constants.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` with the sequenced
  `curl` stub, the recording `sleep` stub, and five new cases.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` carrying
  the retry contract and its cap.
- A regenerated deployed `.claude/` tree.
- `specs/600_sapience_retrieve_cold_start_retry/summaries/01_sapience-retrieve-cold-start-retry-summary.md`
  at completion.

## Rollback/Contingency

Every phase is a content-only edit to one of three source-store files, each independently
revertible with a targeted `git checkout <sha> -- <path>` on a clean tree followed by
`deploy-headless.sh` to regenerate the deployed mirror. If the retry turns out to stall dispatch
construction in practice, reverting Phase 2's hunk alone restores the exact prior behavior — the
harness extension (Phase 1) and the documentation (Phase 4) are independently harmless, though
Phase 4's prose would then need reverting too for accuracy. Before any rollback that would
discard uncommitted work, run `bash .claude/scripts/git-snapshot.sh 600` first.
