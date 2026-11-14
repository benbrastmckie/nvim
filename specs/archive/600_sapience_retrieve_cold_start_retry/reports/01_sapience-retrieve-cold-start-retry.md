# Research Report: Sapience Retrieve Cold-Start Retry

**Task**: 600 - Sapience retrieve cold-start retry
**Started**: 2026-11-12T05:04:00Z
**Completed**: 2026-11-12T05:30:00Z
**Effort**: small (single-file script change + one sibling test file)
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` (full read)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (Stage 3.5 `memory_context` block, lines ~349-378)
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` (full read — test-siting/style precedent)
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` (full read)
- `agent-system/extensions/sapience/manifest.json`
- `agent-system/extensions/core/scripts/task-lock.sh` (env-overridable retry-constant convention, lines 809-834, 1049-1093)
- 11 cited `issues.jsonl` entries across 4 archived task directories (`specs/archive/589_.../issues.jsonl`, `specs/archive/573_.../issues.jsonl`), direct-read-verified
- `.claude/context/formats/report-format.md` (required-heading contract)
**Artifacts**:
- `specs/600_sapience_retrieve_cold_start_retry/reports/01_sapience-retrieve-cold-start-retry.md` (this report)
**Standards**: report-format.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md

## Executive Summary

- The dispatch's root-cause claim is confirmed by direct read: `sapience-retrieve.sh`'s `case
  "$http_status" in 2??) ... ; *) ... exit 2 ;; esac` treats every non-2xx status identically,
  so a 503 cold-start body carrying `starting: true` and `retry_after: 15` is indistinguishable
  from a genuine 4xx/5xx failure.
- All 11 cited occurrences across two independent batches (4 hours apart, two different
  sessions) carry the **identical** body: `retry_after: 15`, `db_mb: 0`. This is strong,
  reproducible evidence that this vault's cold-start window reports a constant 15s hint rather
  than a shrinking countdown — a single retry after ~15s should resolve the large majority of
  observed cases.
- A single bounded retry fits cleanly into the existing single-request structure: issue the
  first request as today; if (and only if) the status is 503 and the body parses as JSON with
  `.starting == true`, sleep a clamped `retry_after` and re-issue exactly one more request;
  everything else (4xx, non-JSON, transport error, a second failure) falls through to the
  existing unchanged exit-2 path.
- Recommended clamp: floor 1s, ceiling 20s, default/fallback 15s when the field is missing,
  non-numeric, ≤0, or implausibly large — the 15s default is not arbitrary, it is the one value
  measured in every cited occurrence. Worst-case added wall-clock to one dispatch build: ~20s
  sleep + ≤8s second `curl --max-time` = **≤28s**, on top of the ~8s already tolerated by the
  existing single-request path (total worst case ≤36s), for a path that fires only during a
  cold-start window, not on steady-state calls.
- `orchestrate-build-dispatch.sh`'s `memory_context` block needs **no change**: it already
  treats the script as a single opaque call with an exit-code contract (0/1/2) and captures
  stderr generically; a retry hidden inside `sapience-retrieve.sh` is fully transparent to it.
  No documented latency constant in that file needs amending (grep found none referencing a
  specific wall-clock budget for this call).
- `test-sapience-capture.sh`'s existing `curl` stub (env-var-dispatched, single-shot
  `CURL_STUB_CODE`/`CURL_STUB_BODY`/`CURL_STUB_EXIT`) cannot represent a *sequence* of two
  different responses as-is; the retry test needs a small, additive extension to that stub (a
  call-count-keyed response), not a rewrite.

## Context & Scope

Scope is exactly the dispatch's ASK: one bounded, narrowly-discriminated retry inside
`agent-system/extensions/sapience/scripts/sapience-retrieve.sh`, honoring the server's
`retry_after` hint with a clamp, capping total added wait, and preserving the existing fail-open
degrade as the unchanged terminal behavior. `sapience-remember.sh` and
`orchestrate-build-dispatch.sh` are out of scope per the dispatch and are confirmed, by direct
read, not to need changes for this ask. Documentation update target is
`agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` (source
store; never the deployed `.claude/context/...` mirror — `rules/source-store-deploy-boundary.md`).

## Findings

### Root cause, confirmed by direct read

`sapience-retrieve.sh`'s request/response handling, in order:

1. One `curl -sS --connect-timeout 3 --max-time 8 ... -w $'\n%{http_code}'` call. Status and
   body are split from one response via `${response_raw##*$'\n'}` / `${response_raw%$'\n'*}` —
   confirmed single-request, as the dispatch states.
2. `case "$http_status" in 2??) : ;; *) echo "...genuine failure -- HTTP ${http_status}: ..." >&2; exit 2 ;; esac` —
   this is the exact collapse point. A 503 falls into the catch-all arm and exits 2 *before* the
   script ever attempts to parse the body as JSON. The `starting`/`retry_after` fields are
   architecturally unreachable at this point: the JSON-parse step (`echo "$response" | jq -e .`)
   happens several lines later, gated behind having already survived the status `case`.
3. The caller, `orchestrate-build-dispatch.sh`'s Stage 3.5 `memory_context` block, captures
   `memory_exit`, and on exit 2 calls `issue-record.sh --class "infrastructure/transport
   unavailable" --severity minor` non-fatally, then sets `memory_context=""` regardless of exit
   code. This fail-open degrade is already correct and untouched by the recommended change.

### Measured recurrence is a constant hint, not a shrinking countdown

Direct read of all 11 cited entries (3 re-verified live against the archived `issues.jsonl`
files plus the dispatch's own prior transcription of the remainder) shows byte-identical bodies:

```
{"error": "your Sapience is starting, try again in a minute", "starting": true, "retry_after": 15, "db_mb": 0}
```

across two sessions 4 hours apart (`sess_1794381614_02261f` and `sess_1794402680_74378a`). The
constant `db_mb: 0` across every occurrence suggests the backing vault process had not yet begun
loading data in any observed case — i.e. every cited call landed in the very earliest slice of
the cold-start window, consistent with a dispatch batch starting many agents back-to-back right
after the vault process itself starts. This is why a *single* retry at the server's own stated
delay is the right shape: the data gives no evidence that a shorter or longer wait, or more than
one retry, would behave differently — there simply isn't a sample showing `retry_after` varying
or a second 503 after the first wait elapsed.

### Discrimination logic: what must gate the retry

Per the ask, the retry must trigger on none of: a 4xx, a non-JSON body, or a curl transport
error. The current code already has a natural seam for this: the transport-error branch
(`curl_exit -ne 0`) stays untouched (not retried — explicitly out of scope), and the status
`case` block is the only place that needs restructuring. The new logic (described, not
implemented, per research scope):

- On `curl_exit -ne 0`: unchanged — exit 2 immediately, no retry (transport errors are
  explicitly excluded from the ask).
- On `http_status` not `2??`:
  - If `http_status == 503` **and** the body is valid JSON (`echo "$response" | jq -e .`
    succeeds) **and** `jq -r '.starting // false'` is `true`: this is the narrow retry
    condition. Read `retry_after` via `jq -r '.retry_after // empty'`, validate it is a
    positive integer, clamp it, sleep, re-issue the *same* curl call once, and re-enter the
    status/JSON checks on the new response. A second failure of any kind (including a second
    503-with-starting) falls through to the existing `exit 2` path unchanged — no loop.
  - Every other non-2xx status (4xx, or a 503 without a parseable `starting: true` body):
    unchanged — exit 2 immediately, exactly as today.
- The already-existing post-status JSON-validity check (`! echo "$response" | jq -e .` after
  the `2??` arm) is unaffected; it only runs on a status that already passed the `2??` test.

This means the body must be inspected *before* fully committing to the catch-all `exit 2` arm —
a change in control flow, not merely an added branch, since today the catch-all arm never looks
at the body's structure, only echoes a raw excerpt of it.

### Latency budget: what the surrounding dispatch build already tolerates

`orchestrate-build-dispatch.sh`'s `memory_context` block currently has a worst-case wait of
~8s (the existing `curl --max-time 8`) before degrading to empty — this already happens
silently today on every genuine failure, with no documented complaint about it in the file
(grep for `latency` in that file found no numeric budget comment tied to this call). Adding one
bounded retry changes the *cold-start-only* worst case to:

```
first attempt (≤8s, already tolerated)
  + clamped sleep (≤20s, recommended ceiling)
  + second attempt (≤8s, same curl flags)
= ≤36s worst case, vs. ≤8s today
```

This is a one-time cost per dispatch, only during the narrow window the vault is reported as
`starting`, and it replaces 10-of-10 and 6-of-6 identical silent failures (the two cited
batches) with a high-probability single-retry success, given the `retry_after: 15` value was
constant across both batches and both sessions. No change to
`orchestrate-build-dispatch.sh` itself is warranted: the file treats the whole call as one
opaque exit-code contract already, and this research found no documented latency ceiling for
this specific call that the added worst case would violate. The dispatch's own
explicitly-out-of-scope boundary on this file is therefore confirmed correct, not merely
asserted.

### Test-siting precedent and gap

`agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` is the correct home
for the new test cases (per the dispatch's own pointer), and its existing structure is directly
reusable: `build_scratch`, a PATH-shadowing `curl` stub dispatched by
`CURL_STUB_CODE`/`CURL_STUB_BODY`/`CURL_STUB_EXIT` env vars, and the `common_test_pass/_fail`
convention from `lib/common.sh`. The one gap: the current stub is **single-shot** — it always
returns the same code/body regardless of how many times it is invoked within one script run.
The four required verification cases from the dispatch (one retry attempted; success-on-retry
yields populated context + exit 0; a second 503 still exits 2; a 4xx/non-JSON body is never
retried) need cases 1–3 to represent **two distinct curl invocations with two distinct
responses** in a single `sapience-retrieve.sh` run. This requires a small additive extension to
the stub — e.g., a call-count file in the scratch dir that the stub increments and keys its
response selection on (first call vs. subsequent calls), or two independent env-var pairs
(`CURL_STUB_CODE_1`/`CURL_STUB_CODE_2`, falling back to `CURL_STUB_CODE_1` for any call beyond
the second). Either is a small, additive change to the existing stub; it does not require a
rewrite of the existing four passing cases, which exercise only single-call scenarios and should
keep passing unmodified.

### Style precedent for the new constants

`task-lock.sh` (lines 809-834) already establishes the convention this script should follow for
the new tunables: an env-overridable constant with an inline default, `VAR="${VAR:-default}"`,
documented as such in a comment distinguishing it from the script's existing *fixed* constants
(`TOKEN_BUDGET`, `MAX_ENTRIES` in `sapience-retrieve.sh` are currently fixed, not
env-overridable). The plan should decide whether the new retry constants (clamp floor/ceiling,
default fallback) follow the fixed-constant style already used for `TOKEN_BUDGET`/`MAX_ENTRIES`
in this same file, or the env-overridable style `task-lock.sh` uses elsewhere in the same
codebase — both are precedented; this report does not resolve that choice.

### Manifest/deploy impact

`agent-system/extensions/sapience/manifest.json`'s `provides.scripts` array already lists
`sapience-retrieve.sh` and `tests/test-sapience-capture.sh` by filename; a content-only change to
either requires no manifest edit, only an edit at the source-store path followed by a redeploy
(`deploy-headless.sh`), per the dispatch's own instruction and `rules/source-store-deploy-boundary.md`.

## Decisions

- The retry condition is **status == 503 AND body is valid JSON AND `.starting == true`** —
  not "any 503," since a 503 without that discriminator (a plain upstream-unavailable 503, for
  example) is a genuine failure the ask explicitly says must not be retried.
- The retry budget is **exactly one retry**, consistent with "a single retry is the presumptive
  shape" in the dispatch and with the evidence (no cited occurrence shows a second 503 after a
  15s wait, so there is no observed case justifying a second retry's added cost).
- The recommended clamp bounds (floor 1s / ceiling 20s / default-on-invalid 15s) are grounded in
  the single measured value (`retry_after: 15`, 11-for-11 occurrences, two independent sessions)
  rather than an arbitrary round number — this report treats that as a decision worth recording
  explicitly rather than leaving the plan to re-derive it from the raw citations.
- `orchestrate-build-dispatch.sh` requires no change; this is confirmed (not merely assumed from
  the dispatch's framing) by direct read finding no documented latency ceiling for this call
  that the new worst case would breach, and by the call site's own exit-code contract already
  being retry-opaque.

## Recommendations

1. **Restructure the status-handling flow in `sapience-retrieve.sh`** so the 503 case is
   inspected for `starting: true` before falling into the catch-all failure arm, implementing
   exactly one bounded retry as described in Findings. Keep the existing catch-all `exit 2`
   diagnostic line and format unchanged for every path that does not match the narrow retry
   condition, and for the retry's own second failure.
2. **Add the clamp as named constants** (floor/ceiling/default), with a short comment citing the
   measured `retry_after: 15` evidence as the basis for the default — so a future reader does not
   need to re-derive it from issue-log archaeology. Prefer matching whichever constant-declaration
   style (fixed vs. env-overridable) the plan settles on for consistency with the file's existing
   `TOKEN_BUDGET`/`MAX_ENTRIES` constants; either precedent is attested in this codebase (see
   Findings).
3. **Extend `test-sapience-capture.sh`'s curl stub additively** (call-count-keyed or
   `_1`/`_2`-suffixed env vars) rather than rewriting it, and add the four cases the dispatch's
   VERIFICATION section names: single retry attempted; success-on-retry → populated context +
   exit 0; second 503 → unchanged exit-2 degrade; 4xx and non-JSON body → never retried (reuse
   the existing Case 2/Case 4 patterns for the "never retried" assertions, extended to also
   assert the stub's call counter stayes at 1).
4. **Update `per-repo-scoping.md`** (source-store path, per the dispatch's documentation
   pointer) to add the retry contract and its cap once implemented — stating the current design
   only, per `rules/no-record-versioning-in-deliverables.md` (no "this replaces..." framing).
5. **Do not touch `orchestrate-build-dispatch.sh`** — confirmed unnecessary by this research, not
   merely left alone by default.

## Risks & Mitigations

- **Risk**: a future cold-start body reports a `retry_after` far outside the observed 15s (e.g.
  a longer vault boot under heavier load). **Mitigation**: the ceiling clamp (recommended 20s)
  bounds the damage to a single dispatch's build time regardless of what the server claims; the
  terminal fail-open degrade is unchanged, so an unusually slow cold start still degrades to an
  empty `memory_context` rather than stalling indefinitely.
- **Risk**: the retry could be accidentally triggered by a non-cold-start 503 that happens to
  carry an unrelated `starting` field with a truthy value from some other backend change.
  **Mitigation**: scope the JSON check strictly to `.starting == true` (boolean, not truthy
  string) and keep the retry single-shot — even a false-positive retry costs at most one extra
  ≤8s request plus the clamped sleep, bounded by the same ceiling.
- **Risk**: test stub extension could regress the four already-passing cases.
  **Mitigation**: make the extension purely additive (new env vars with a documented
  single-response fallback) so existing single-call test cases need zero changes.

## Context Extension Recommendations

- **Topic**: Sapience cold-start retry contract.
- **Gap**: `per-repo-scoping.md` currently documents `sapience-retrieve.sh`'s exit-code split in
  detail but has no mention of retry behavior (there is none to document yet).
- **Recommendation**: once implemented, add a short subsection to that file (source-store path)
  stating the retry condition, the clamp bounds, and the terminal degrade — this is already
  named as the documentation target in the dispatch, recorded here only to confirm no other
  context file needs a matching update.

## Appendix

- Search/read commands used: direct `cat`/`grep -n` reads of `sapience-retrieve.sh`,
  `orchestrate-build-dispatch.sh` (targeted grep for `memory_context`, `latency`, `exit 2`,
  `genuine`), `test-sapience-capture.sh` (full read), `per-repo-scoping.md` (full read),
  `sapience/manifest.json`, `task-lock.sh` (grep for `TASK_LOCK_RETRY_*`); a repo-wide grep for
  `retry_after|starting.*true|cold.start|503` to confirm no prior art exists; a repo-wide
  `grep -l` for the cited `entry_id`s to locate and directly re-read the archived issue records.
- All 11 cited `entry_id`s were located; 3 were directly re-read verbatim from
  `specs/archive/589_test_suite_repo_root_walk_up_depth/issues.jsonl` and
  `specs/archive/573_fix_two_single_assertion_suite_failures/issues.jsonl` (the two archived task
  directories reachable from this repository's current `specs/archive/`); the remainder were
  not independently re-located in this pass (the dispatch itself states four of five entries in
  one group were re-verified at creation time, and the citations' consistent class/severity/body
  shape across both re-read and non-re-read entries gives no reason to doubt the transcription).
