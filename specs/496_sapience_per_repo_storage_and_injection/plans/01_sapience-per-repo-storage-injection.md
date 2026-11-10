# Implementation Plan: Task #496

- **Task**: 496 - Add per-repo storage and injection to the sapience extension
- **Status**: [IMPLEMENTING]
- **Effort**: 8.5 hours
- **Dependencies**: 360, 449, 450, 487, 488 (all `completed` in `specs/state.json` — edges satisfied, retained as shared-territory record)
- **Research Inputs**: specs/496_sapience_per_repo_storage_and_injection/reports/01_sapience-per-repo-storage-injection.md
- **Artifacts**: plans/01_sapience-per-repo-storage-injection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Give the sapience extension two new shell scripts — `sapience-retrieve.sh` (repo-filtered
`GET /v1/search` read emitting the existing `<memory-context>` envelope) and
`sapience-remember.sh` (repo-tagged, `explicit: true` `POST /ingest-kos` write) — declare them in
the extension's `manifest.json` `provides.scripts` array so the deploy places them in
`.claude/scripts/`, then swap the retrieval call in core's
`orchestrate-build-dispatch.sh` Stage 3.5 `memory_context` block from `memory-retrieve.sh` to
`sapience-retrieve.sh` while preserving the `--clean` guard and the failure-swallowing
`2>/dev/null) || memory_context=""` wrapper byte-for-byte in shape. The extension's own design
record, which currently argues against exactly this mechanism, is amended in the same task, and
the three named hazards (no delete API, unreviewed permanent writes, two differently-shaped vault
populations) are documented rather than fixed.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class line the dispatch extracted was checked against live state. Results, stated
explicitly even where they only confirm the description:

1. **"SOURCE STORE IS THE EDIT TARGET … Resolve `source_dir` from
   `<project-root>/.claude-extensions.json`"** — CONFIRMED with one precision correction:
   `.claude-extensions.json` has **no top-level `source_dir` key** (`jq -r '.source_dir'` returns
   `null`). It is a **per-extension** key: `.extensions.sapience.source_dir` =
   `/home/benjamin/.config/nvim/agent-system/extensions/sapience` and
   `.extensions.core.source_dir` = `/home/benjamin/.config/nvim/agent-system/extensions/core`.
   The edit targets the description names are therefore correct; only the lookup path is
   per-extension rather than top-level.
2. **"`mcp.py`'s `remember_provenance()` hardcodes provenance … an unknown `SAPIENCE_CLIENT`
   collapses to the label `AI`"** — CONFIRMED verbatim at `~/.sapience/mcp.py:111-120`: the
   function returns `((name + ' ') if name else '') + 'via %s session (MCP)' % label` with
   `label` taken from a six-key dict whose `.get(..., 'AI')` default is the `AI` collapse. The
   `sapience_remember` call site (`~/.sapience/mcp.py:1512-1513`) sets
   `"provenance": remember_provenance()` with no caller-injectable component. **Narrowing
   nuance** (not a contradiction): the MCP tool *can* set `explicit=True` via its `user_asked`
   argument, but doing so appends the fixed literal `EXPLICIT_PROVENANCE = ', asked by the user'`
   and still admits no repo marker — so the description's conclusion (the MCP tool is unusable
   for **tagged** writes) holds exactly as stated.
3. **"`explicit: true` IS MANDATORY … The script MUST treat `gated >= 1` as a loud, reported
   outcome"** — the live-host measurement was not re-derived (the dispatch forbids it) and is
   accepted. It is CORROBORATED from the vendor client: `~/.sapience/mcp.py` branches explicitly
   on `r.get('gated')` after `/ingest-kos` and returns a distinct non-success message.
   **NEW FINDING the description does not name**: the same call site branches on
   `r.get('set_aside')` **first** — a *second* silent-loss response shape, carrying a
   per-item `why`/`id` list. A script that checks only `gated` would swallow a `set_aside`
   response as success. Both shapes are therefore in scope for Phase 2's loud-failure handling.
4. **"The transcript-extraction path CANNOT be repo-tagged"** — not independently re-derived
   (dispatch-settled). Consistent with the extension's existing
   `domain/transcript-filter-ceiling.md` and `domain/review-gate-boundary.md`, which already
   describe that path as classify-and-stage with no caller-supplied provenance.
5. **"`orchestrate-build-dispatch.sh` is shared file territory with four non-terminal records
   (360, 449, 450, 487) … 488 is declared"** — PARTIALLY SUPERSEDED by live state. All five are
   present in this task's `dependencies` array, and `specs/state.json` now reports **all five as
   `completed`** (360, 449, 450, 487, 488), not non-terminal. The declared edges are satisfied,
   so they impose no sequencing constraint on this task; the file remains shared territory and
   the batching rule's edge-not-exclusion ruling still stands as the record of why the edges
   exist.
6. **Call-site shape** — CONFIRMED verbatim at
   `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh:349-355`, with the call on
   line 354 and the `memory_context` consumer check at lines 831-832.
7. **`provides.scripts: []`** — CONFIRMED: the sapience manifest declares every `provides` array
   empty except `context: ["project/sapience"]`, and the extension has **no `scripts/`
   directory** at all. Both new scripts are greenfield additions.

### Research Integration

Findings carried into the phase design:

- **Auth is a `token=` query-string parameter, not a Bearer header** — `~/.sapience/mcp.py`'s
  `api()` helper builds `HOST + path + ('&' if '?' in path else '?') + 'token=' + quote(token)`
  for every endpoint it calls, `/v1/search` and `/ingest-kos` included. Credential precedence to
  mirror: `SAPIENCE_TOKEN` env, else `~/.sapience/config.json`'s `.token`; host from
  `SAPIENCE_HOST`, else `.host`, else the `https://app.spnc.ai` literal.
- **The repo tag and `explicit: true` are fields of the KO object inside `kos[0]`**, not sibling
  top-level body fields. Body shape:
  `{"token": …, "kos": [{subject, predicate, object_value, ko_type, confidence, provenance,
  explicit, source_loc?}], "source": "…"}`.
- **The manifest declaration is load-bearing, not cosmetic.** The dispatch call site invokes the
  script at its **deployed** path (`${SKILL_REPO_ROOT}/.claude/scripts/…`). Adding the file under
  the extension's `scripts/` directory without a `provides.scripts` entry would leave the swapped
  call site pointing at a file that never lands in the deployed tree. `sync-manifest-scripts.sh`
  (check mode) **fails** on an on-disk script absent from `provides.scripts`, and `--write`
  inserts it surgically — so this is a one-command step, not a hand edit.
- **`subagent-orientation.md` currently argues against this exact mechanism.** Its "The
  Deliberate Alternative" section, item 3, states that building a Sapience equivalent of
  `<memory-context>` by editing core's `orchestrate-build-dispatch.sh` "is exactly the second
  always-on injection path this extension's anti-goal forbids." That is the thing this task
  builds. The file is amended in Phase 5, not left to contradict the shipped code.

Findings surfaced during this planning pass that neither the dispatch nor the report records:

- **The existing dispatch test suite installs a `memory-retrieve.sh` stub and asserts on it.**
  `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` writes an
  executable stub to `$FIXTURE/.claude/scripts/memory-retrieve.sh` emitting
  `STUB_MEMORY_CONTENT`, and Group 2 asserts both `<memory-context>` and `STUB_MEMORY_CONTENT`
  are present while Group 1 asserts `<memory-context>` is absent under `--clean`. Swapping the
  call site without renaming that stub path turns Group 2 red. This is why the test file is in
  the task's declared `file_scope` and why it is edited in the same phase as the swap.
- **A bounded timeout is required, not merely a failure-swallowing wrapper.** `|| memory_context=""`
  catches a *failure*; it does not catch a *hang*. The swapped call is a network round-trip on
  every dispatch, so an unresponsive host would stall dispatch building indefinitely without an
  explicit `curl --connect-timeout`/`--max-time`. The dispatch's "an outage must not break every
  dispatch in a batch" invariant is only actually satisfied with both.
- **`printf '%b'` is unsafe for server-sourced text.** `memory-retrieve.sh` emits its envelope
  with `printf '%b' "$output"`, which interprets backslash escapes. Applied to KO field values
  returned by `/v1/search`, a literal `\n` or `\t` in the stored text would be silently
  reinterpreted. The new script builds real newlines and emits with `printf '%s'`.
- **The local retrieval-metadata update stage has no server-side equivalent.**
  `memory-retrieve.sh` lines 165-176 increment `retrieval_count`/`last_retrieved` in
  `.memory/memory-index.json`. `sapience-retrieve.sh` simply omits that stage; there is no
  writable counterpart and no attempt should be made to synthesize one.
- **`index-entries.json` carries a per-entry `line_count`.** Editing any domain file changes its
  line count, and adding a new domain file needs a new entry plus a row in the context
  `README.md` loading-strategy table. `test-index-entries-schema.sh` and
  `test-context-reachability.sh` are the covering checks.

### Prior Plan Reference

No prior plan. `specs/496_sapience_per_repo_storage_and_injection/plans/` is empty and this is
artifact round 01.

### Roadmap Alignment

`specs/ROADMAP.md` tracks this record as `496 blocked:360,449,450,487,488` and describes the
sapience migration as "nine waves deep, and only one of its six records is done." This task is
the dependency root of that strand: `499` (retire the memory extension) cannot proceed until a
working Sapience-backed replacement for `memory-retrieve.sh`'s injection role exists. All five
declared blockers now read `completed`, so landing this record unblocks the strand's next wave.
This plan does not modify ROADMAP.md (read-only consultation; `roadmap_flag` not set).

## Goals & Non-Goals

**Goals**:
- A `sapience-retrieve.sh` that performs a repo-filtered `/v1/search` read and emits an envelope
  shape-identical to `memory-retrieve.sh`'s, under the same 2000-token budget and 5-entry cap,
  with the same exit-code contract (exit 1 + empty stdout on every failure or no-match path).
- A `sapience-remember.sh` that writes a repo-tagged, `explicit: true` KO via `POST /ingest-kos`
  and reports `gated`, `set_aside`, and `written == 0` as loud, non-zero-exit failures.
- Both scripts declared in the sapience extension's `provides.scripts` and present in the
  deployed `.claude/scripts/` tree after a redeploy.
- The dispatch call site swapped with the `--clean` guard, the failure-swallowing wrapper, the
  `memory_context` variable name, and the argument list and count all unchanged.
- The extension's design record amended so it no longer contradicts the shipped mechanism, and
  the three named hazards documented.

**Non-Goals**:
- Re-deriving the settled live-host findings (repo-tag-in-`provenance` scoping, the `project=`
  dead end, the noise gate, the absent delete API, the 0.22s latency). The dispatch forbids it.
- Wiring `sapience-remember.sh` into any call site. The description names the script as the
  deliverable; where it is called from is a separate record's ground. This plan documents the
  sanctioned call site (task-boundary postflight, a bounded 3-8-note set) without creating it.
- Fixing the two-population asymmetry between repo-tagged live writes and untagged
  transcript-extraction writes. Explicitly scoped as document-don't-fix.
- Removing the memory extension, `memory-retrieve.sh`, or `.memory/`. That is `499`'s ground;
  this task leaves `memory-retrieve.sh` on disk and deployed, merely no longer called from the
  dispatch builder.
- Deleting the two orphaned probe KOs. There is no delete API; they are recorded as a manual
  app.spnc.ai cleanup item, not implementation work.
- A shared `scripts/lib/http-client-common.sh`. The research recommends considering one only
  after a third such integration appears; building it here would add an undeclared path outside
  the task's `file_scope`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Retrieval host unreachable or slow stalls every dispatch in a batch | H | M | `curl --connect-timeout 3 --max-time 8` inside the script **and** the preserved `2>/dev/null) || memory_context=""` wrapper at the call site. Verified in Phase 6 by pointing `SAPIENCE_HOST` at an unroutable host and confirming the dispatch still builds |
| Writes are permanent — no delete API on any of three probed routes | H | H | `explicit: true` plus a loud `gated`/`set_aside`/`written == 0` failure path so nothing is lost invisibly; documented bound of few, high-value, well-formed writes at a task boundary; **verification writes themselves are crafted as genuinely useful notes**, since an un-gated probe cannot be retracted |
| Test suite Group 2 turns red because the fixture stub still writes `memory-retrieve.sh` | M | H | Stub path and its comment renamed in the same phase as the call-site swap; `run-all.sh --only` over the selector-resolved suite list run before the phase closes |
| Manifest entry omitted, so the deployed call site points at a missing script | H | M | `sync-manifest-scripts.sh --write` then `--check` (which fails on an undeclared on-disk script) in Phase 4, **before** the swap in Phase 5 — so the window where the call site references a missing file never exists |
| Token leaked into logs, stderr, a temp file, or a dispatch artifact | H | L | Read the token once into a local variable, pass it only inside the URL given to `curl`, never `echo`/`set -x` it, never write it to a file; `--fail-with-body`-free error reporting that prints the response body only, never the request URL |
| Amending `subagent-orientation.md` introduces record-versioning language the rules forbid | M | M | Use the single sanctioned form — a dated `**Amended by** <doc>, <date>:` cross-document note — and no "no longer"/"previously"/"supersedes v1" phrasing; see `rules/no-record-versioning-in-deliverables.md` |
| A task number leaks into a deliverable under `agent-system/**` | L | M | `rules/no-task-references-in-deliverables.md`: cite the durable anchors (file paths, section headings) instead; gate 4 (task-reference lint) is in the Phase 6 gate set |
| `printf '%b'` reinterprets backslashes in server-sourced KO text | M | M | Build the envelope with real newlines and emit with `printf '%s'`; compare shape against `memory-retrieve.sh`'s output in Phase 6 |
| Bracket URL-encoding of the `source=[repo:<slug>]` filter is fragile | M | L | URL-encode the brackets (`%5Brepo%3A<slug>%5D`) rather than relying on the measured bracket-free substring form, which would also match a longer slug sharing the prefix |
| Repo slug underivable (not a git repo, `git` absent) | L | L | Treat as a failure path: exit 1 with empty stdout, which the call-site wrapper degrades to no injection |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4, 6 | 3 |
| 4 | 5 | 4 |
| 5 | 7 | 5, 6 |

Phases within the same wave can execute in parallel, with one practical caveat: Phases 4 and 7
each declare `__WHOLE_TREE__` because they run `deploy-headless.sh`, which regenerates the whole
deployed tree. Neither may actually run concurrently with any other phase, so Wave 3's grouping of
4 with 6 is a dependency statement, not an invitation to interleave them — run 6 before or after
4, never during.

---

### Phase 1: Author `sapience-retrieve.sh` [COMPLETED]

**Goal**: A standalone, shellcheck-clean retrieval script that queries `/v1/search` filtered to
this repo's tag and emits the existing `<memory-context>` envelope under the existing budget.

**Tasks**:
- [x] Create `agent-system/extensions/sapience/scripts/` and write `sapience-retrieve.sh` with *(completed)*
      the bootstrap every sibling in `.claude/scripts/` uses: `SCRIPT_DIR` resolution,
      `source "${SCRIPT_DIR}/lib/common.sh"`, `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"`,
      `. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1`, and `set -euo pipefail`.
- [x] Mirror `memory-retrieve.sh`'s argument contract exactly: `<description> <task_type> *(completed)*
      [focus_prompt]`, exiting 1 when either of the first two is empty — so the Phase 5 swap
      changes only the script path, never the argument list or count.
- [x] Declare `TOKEN_BUDGET=2000` and `MAX_ENTRIES=5` as named constants, as the existing script *(completed)*
      does, and send `limit=5` on the request so the entry cap is satisfied server-side.
- [x] Reuse `memory-retrieve.sh`'s keyword-extraction stage verbatim (its lines 58-68: the *(completed)*
      `STOP_WORDS` alternation, `tr '[:upper:]' '[:lower:]'`, `tr -cs '[:alpha:]' '\n'`, the
      stop-word `grep -v -E`, `awk 'length > 3'`, `sort -u`, `head -10`), copied rather than
      reinvented. Exit 1 when the extraction yields nothing.
- [x] Derive the repo slug as `basename "$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel)"`, *(completed)*
      exiting 1 if that fails for any reason, so the script works unmodified in every repo the
      system deploys into.
- [x] Resolve host and token with `mcp.py`'s own precedence: `SAPIENCE_HOST` env, else *(completed)*
      `~/.sapience/config.json`'s `.host`, else the `https://app.spnc.ai` literal; `SAPIENCE_TOKEN`
      env, else that file's `.token`. Exit 1 when no token resolves. Never echo, log, `set -x`,
      or write the token.
- [x] Issue `curl -sS --connect-timeout 3 --max-time 8 -H 'X-Sapience-Client: …'` against *(completed)*
      `${HOST}/v1/search?q=<urlencoded keywords>&source=%5Brepo%3A<slug>%5D&limit=5&token=<token>`,
      URL-encoding the filter's brackets rather than relying on the bracket-free substring form.
- [x] Synthesize a title and body per hit from the returned KO's `subject`/`predicate`/ *(completed)*
      `object_value` fields (there is no local file per hit), estimate each hit's token cost with
      the same rough heuristic the existing script applies, and greedily select within
      `TOKEN_BUDGET` in the same shape as that script's reduce-based selection.
- [x] Emit the envelope with real newlines and `printf '%s'` (never `printf '%b'`, which would *(completed)*
      reinterpret backslashes in server-sourced text): the literal `<memory-context>` open tag,
      the same one-line preamble sentence, one `### <title> (relevance: <score>)` heading per hit
      followed by its body and a blank line, then `</memory-context>`.
- [x] Omit any retrieval-metadata update stage — there is no server-side counterpart to *(completed)*
      `memory-retrieve.sh`'s local `retrieval_count`/`last_retrieved` write.
- [x] Honour the exit-code contract: exit 1 with empty stdout on every failure or empty-result *(completed)*
      path (no token, no slug, no keywords, curl non-zero, non-JSON body, zero hits, zero hits
      surviving the budget); exit 0 with the envelope otherwise.
- [x] Run `shellcheck` on the new file and fix every finding. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select agent-system/extensions/sapience/scripts/sapience-retrieve.sh` returns `__FULL_SWEEP__` — no suite maps to this new path — so the honest covering check is the `local` row's single-module lint, `shellcheck agent-system/extensions/sapience/scripts/sapience-retrieve.sh` plus a direct invocation of the script, and no suite is claimed.

**Scope Hypothesis**: This phase hypothesises that `memory-retrieve.sh`'s keyword-extraction stage is self-contained within its lines 58-68 and depends on nothing but `$combined_text` and `$STOP_WORDS`. Confirm at implementation time by reading those lines in the source store and checking that no variable they reference is set outside that block; if the block turns out to depend on earlier state, copy that dependency too rather than silently dropping it.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` - new file, the retrieval script

**Verification**:
- `shellcheck` exits 0 on the new file.
- Invoked with a real description and `task_type`, the script exits 0 and stdout opens with
  `<memory-context>` and closes with `</memory-context>`; or exits 1 with empty stdout when the
  repo has no tagged KOs yet (both are correct outcomes at this phase, since no tagged write has
  happened).
- Invoked with an empty description, it exits 1 and prints nothing to stdout.
- `SAPIENCE_HOST=http://127.0.0.1:1` (unroutable) makes it exit non-zero within the `--max-time`
  bound and print nothing to stdout.
- `grep` of the script confirms the token variable is never passed to `echo`, `printf`, or a
  redirect, and that `set -x` appears nowhere.

---

### Phase 2: Author `sapience-remember.sh` [COMPLETED]

**Goal**: A standalone, shellcheck-clean write script that posts a repo-tagged, `explicit: true`
KO and fails loudly on every silent-loss response shape the server can return.

**Tasks**:
- [x] Write `agent-system/extensions/sapience/scripts/sapience-remember.sh` with the same *(completed)*
      bootstrap, `set -euo pipefail`, and host/token/slug resolution as Phase 1. The resolution
      block is deliberately **copied, not shared** — a `scripts/lib/` helper would add a path
      outside this task's declared `file_scope`; record the duplication in a header comment
      pointing at the other script.
- [x] Define the argument contract: `--subject S --value V` required; `--predicate P` (default *(completed)*
      `finding is`), `--ko-type T` (default `insight`), `--confidence C` (default `0.8`) — the
      three defaults matching `~/.sapience/mcp.py`'s own `sapience_remember` call site —
      `--source-loc L` optional, and `--dry-run`. Refuse unknown flags with a non-zero exit
      rather than ignoring them.
- [x] Build the `provenance` string so it contains the literal `[repo:<slug>]` tag plus a *(completed)*
      human-meaningful remainder naming the writing surface, and document the shape in a header
      comment as the one field per-repo scoping depends on.
- [x] Build the request body with `jq -n` (never string concatenation) in the confirmed nesting: *(completed)*
      `{"token": …, "kos": [{subject, predicate, object_value, ko_type, confidence, provenance,
      explicit: true, source_loc?}], "source": "…"}`. `explicit: true` is set unconditionally and
      is not switchable off by any flag.
- [x] Under `--dry-run`, print the body to stdout **with the token field redacted** and exit 0 *(completed)*
      without issuing any request.
- [x] Otherwise `POST` to `${HOST}/ingest-kos?token=<token>` with *(completed)*
      `-H 'content-type: application/json' -H 'X-Sapience-Client: …'` and the same
      `--connect-timeout`/`--max-time` bounds.
- [x] Interpret the response as a **loud** outcome, not a success, whenever any of these holds: *(completed)*
      `gated` is `>= 1`; `set_aside` is a non-empty array (the second silent-loss shape, found in
      the vendor client at `~/.sapience/mcp.py`'s `sapience_remember` call site, which branches on
      it before `gated`); `written` is absent or `0`; `ok` is falsey; or the body is not JSON. In
      each case print a message to stderr naming the response field that triggered it, echo the
      server's own `why` text when `set_aside` supplies one, and exit non-zero — explicitly
      including the `{"ok": true, "written": 0, "gated": 1}` shape, whose `ok: true` must not be
      read as success.
- [x] Print a one-line confirmation to stdout on a genuine `written >= 1`, and exit 0. *(completed)*
- [x] Add a header comment stating the sanctioned call site (task-boundary postflight, a bounded *(completed)*
      3-8-note set) and the reason for the bound: writes through this path are permanent and
      unreviewed, and no delete API exists.
- [x] Run `shellcheck` and fix every finding. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select agent-system/extensions/sapience/scripts/sapience-remember.sh` returns `__FULL_SWEEP__` — no suite maps to this new path — so the honest covering check is the `local` row's single-module lint, `shellcheck agent-system/extensions/sapience/scripts/sapience-remember.sh` plus `--dry-run` invocations, and no suite is claimed.

**Scope Hypothesis**: This phase hypothesises that `gated`, `set_aside`, and a zero/absent `written` are the complete set of non-success response shapes `/ingest-kos` can return. That set was derived from reading the vendor client's own branches, not from an exhaustive server contract. Confirm at implementation time by re-reading the `sapience_remember` branch sequence in `~/.sapience/mcp.py`; if it checks a fourth key, handle that one too rather than treating the three as closed.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-remember.sh` - new file, the write script

**Verification**:
- `shellcheck` exits 0 on the new file.
- `--dry-run --subject X --value Y` prints a body that `jq -e` parses, in which
  `.kos[0].explicit == true`, `.kos[0].provenance` contains `[repo:` plus this repo's slug,
  `.kos[0].predicate == "finding is"`, `.kos[0].ko_type == "insight"`,
  `.kos[0].confidence == 0.8`, and the token field is redacted rather than printed.
- Invoked with `--subject` missing, it exits non-zero without issuing a request.
- Invoked with an unknown flag, it exits non-zero without issuing a request.
- `grep` of the script confirms `explicit` is set to `true` at exactly one site and is not
  reachable from any flag, and that all three of `gated`, `set_aside`, and `written` appear in
  the response-handling branch.
- No live write is issued in this phase; the first real write happens in Phase 4, deliberately,
  once the script is deployed.

---

### Phase 3: Declare both scripts in the extension manifest [COMPLETED]

**Goal**: `provides.scripts` lists both new scripts, so the deploy places them at
`.claude/scripts/sapience-retrieve.sh` and `.claude/scripts/sapience-remember.sh`.

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` and *(completed)*
      confirm it now reports the two on-disk sapience scripts as undeclared — the expected
      failure that proves the gap this phase closes.
- [x] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write` to insert *(completed)*
      both entries surgically into `agent-system/extensions/sapience/manifest.json`'s
      `provides.scripts` array, rather than hand-editing it or round-tripping the document
      through `jq`.
- [x] Re-run `--check` and confirm it now passes, and review `git diff` to confirm **only** the *(completed)*
      `provides.scripts` array changed and no unrelated key was reformatted.
- [x] Confirm the two inserted entries are bare relative paths under `scripts/` matching the *(completed)*
      convention the memory extension's own four entries use.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Scope Hypothesis**: This phase's Tier Justification asserts that `suite_selection_select` resolves `manifest.json` to 28 suites. That figure came from running the selector during plan authoring, not from a contract. Confirm at implementation time by re-running `suite_selection_select agent-system/extensions/sapience/manifest.json | wc -l`; if the count differs, the tier conclusion (no cheaper subset is honest) still holds as long as the list spans more than one suite family, but correct the figure in the phase record rather than carrying a stale one.

**Verification Tier**: full

**Tier Justification**: `manifest.json` is deploy-global configuration whose `provides.scripts` array is read by the deploy ledger, the install/uninstall path, and the extension-docs lint simultaneously, and `suite_selection_select` on it resolves to 28 suites spanning deploy propagation, gate equivalence, routing resolution, and script inventory — effectively the whole Gate 8 battery, so no cheaper subset honestly covers this edit.

**Files to modify**:
- `agent-system/extensions/sapience/manifest.json` - add both script entries to `provides.scripts`

**Verification**:
- `sync-manifest-scripts.sh --check` exits 0.
- `jq -r '.provides.scripts[]' agent-system/extensions/sapience/manifest.json` lists exactly the
  two new scripts.
- `git diff --stat` shows `manifest.json` as the only changed file in this phase, and
  `git diff` shows changes confined to the `provides.scripts` array block.
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set) exits 0. *(deviation: altered —
  run once pre-deploy; gate 5 correctly failed with "sapience: Missing scripts:
  scripts/sapience-remember.sh / scripts/sapience-retrieve.sh" because the manifest now declares
  both scripts but Phase 4's redeploy has not yet placed them in the deployed tree. This is the
  expected pre-deploy state, not a defect. Re-run after Phase 4's redeploy, where gate 5 is
  expected to clear.)*

---

### Phase 4: Deploy and verify the live write/read round trip [COMPLETED]

**Goal**: Both scripts present in the deployed tree, and the repo-scoping mechanism verified
end-to-end against the live host: a tagged write is returned by a matching repo filter and not by
a different one, and a gated write is reported rather than swallowed.

**Tasks**:
- [x] Redeploy with the bounded-wait idiom the dispatch mandates: *(completed)*
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked through the Bash tool with
      its `timeout` parameter raised to 600000 (not the 120000ms default), per
      `context/patterns/external-process-wait.md` Rule 1. This also clears the `core` staleness
      the dispatch's deploy-freshness notice reports.
- [x] Confirm `.claude/scripts/sapience-retrieve.sh` and `.claude/scripts/sapience-remember.sh` *(completed)*
      both exist and are executable in the deployed tree.
- [x] **V2 — tagged write.** Issue exactly **one** live write via the deployed *(completed)*
      `sapience-remember.sh`. Because there is no delete API, craft it as a genuinely useful,
      well-formed note about this repo (for example, the measured fact that per-repo scoping in
      this vault works only through a `provenance` repo tag filtered by `source=`), never a
      throwaway probe — an un-gated write cannot be retracted. Confirm the script reports
      `written >= 1` and exits 0.
- [x] **V3a — matching filter returns it.** Run the deployed `sapience-retrieve.sh` with a *(completed)*
      description whose keywords overlap that note and confirm the emitted `<memory-context>`
      block contains it.
- [x] **V3b — non-matching filter does not.** Re-run the same query with the repo filter forced *(completed)*
      to a different repo's tag (via a deliberate one-off override, not a script edit) and
      confirm the note is absent from the result.
- [x] **V4 — gated write is loud.** Issue one write whose text is deliberately operational *(completed)*
      chatter and whose `explicit` flag is suppressed **only** by a temporary local edit reverted
      immediately afterwards (never a permanent flag), or by calling the endpoint directly with
      the same body minus `explicit`. Confirm the response carries `gated >= 1` with
      `written: 0`, that the script exits non-zero and names the triggering field on stderr, and
      that nothing permanent landed. Revert any temporary edit and re-confirm `explicit: true` is
      unconditional.
- [x] Record the two orphaned probe KO hashes (`806180dc43c5cb34`, `9ba2b479b5e4a7e2`) plus any *(completed)*
      permanent KO this phase's V2 wrote, as a manual app.spnc.ai cleanup item for the completion
      summary.
- [x] Record an issue-log entry (`issue-record.sh`) for any live-host deviation from the measured *(completed)*
      behavior this plan assumes.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Tier Justification**: This phase runs `deploy-headless.sh`, which regenerates the entire deployed `.claude/` tree, so its blast radius is every deployed consumer at once — a surface no suite subset or gate subset can bound.

**Scope Hypothesis**: This phase hypothesises that a redeploy is sufficient to place both scripts in `.claude/scripts/` with no further wiring, on the strength of the memory extension's four `provides.scripts` entries landing the same way. Confirm by listing both deployed paths immediately after the deploy; if either is absent, investigate `sync-manifest-scripts.sh`'s declared-path form before proceeding to Phase 5, because the Phase 5 swap depends on the deployed path resolving.

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree
- (no source-store file is edited in this phase; any temporary edit made for V4 is reverted
  within the phase)

**Verification**:
- `deploy-headless.sh` exits 0 within the 540s bound.
- Both deployed script paths exist and are executable.
- V2 reports `written >= 1` and exits 0.
- V3a finds the note under the matching repo filter; V3b does not find it under a different
  repo's filter.
- V4's response carries `gated >= 1`, the script exits non-zero, and its stderr names the
  triggering response field.
- `git status --short` shows no leftover temporary edit from V4.
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set) exits 0. *(deviation: altered —
  `deploy-headless.sh` landed the deploy (RESULT=landed_verify_red) but its internal
  `--skip-slow` post-check reported 6 failures. Gate 5 (the one this phase's own change could
  have affected) now PASSES post-deploy, confirming the manifest/deploy sync is correct. The
  remaining 6 (gates 3/4/10 60s timeouts; gate 20 eager-load budget; gate 22 shellcheck -- 3
  findings, none in the two new sapience scripts, confirmed by direct
  `lint-shellcheck.sh --verbose` re-run; gate 24 dead-command-recommendation, confirmed no
  "sapience" match) are pre-existing/unrelated to this task's `file_scope` -- task 476
  ("isolate seven RED gate8 shell suites") independently tracks this repo's known baseline
  gate8-adjacent red state. Not fixed here; out of scope. Full gate set re-run at Phase 7.)*

---

### Phase 5: Swap the dispatch retrieval call site [NOT STARTED]

**Goal**: Stage 3.5's `memory_context` block calls `sapience-retrieve.sh` instead of
`memory-retrieve.sh`, with the `--clean` guard, the failure-swallowing wrapper, the variable
name, and the argument list all unchanged — and the test suite's fixture stub follows.

**Tasks**:
- [ ] In `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`, change **only the
      script basename** on the call line inside the existing `memory_context` block: the
      right-hand side becomes
      `$(bash "${SKILL_REPO_ROOT}/.claude/scripts/sapience-retrieve.sh" "$description" "$task_type" "$memory_arg3" 2>/dev/null) || memory_context=""`.
      Keep the `if [ "$clean_flag" != "true" ]; then` guard, the `memory_arg3` derivation, the
      `2>/dev/null` redirect, the `|| memory_context=""` fallback, the variable name
      `memory_context`, and the three positional arguments exactly as they are.
- [ ] Leave the consumer check untouched — `memory_context` is read later in the same script as a
      plain string-emptiness test, and keeping the variable name means that site needs no edit at
      all, which is what holds this phase's footprint on a shared-territory file to one line plus
      its comment.
- [ ] Update the block's section comment so it names the retrieval source accurately without
      narrating the change (no "no longer", no "previously" — see
      `rules/no-record-versioning-in-deliverables.md`) and without citing a task number (see
      `rules/no-task-references-in-deliverables.md`).
- [ ] In `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`, rename
      the fixture stub from `$FIXTURE/.claude/scripts/memory-retrieve.sh` to
      `$FIXTURE/.claude/scripts/sapience-retrieve.sh` (both the heredoc target and the `chmod +x`
      line), and update the stub's explanatory comment, which currently calls it a stand-in for
      "the real memory vault". Leave the stub's emitted marker text and every assertion string
      (`<memory-context>`, `STUB_MEMORY_CONTENT`) unchanged — the envelope tag is deliberately
      preserved so no consumer and no assertion needs changing.
- [ ] Also update the suite's header comment, which enumerates the stubbed scripts by name.
- [ ] Run the selector-resolved suite subset and confirm green:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-force-phases.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-record-decision.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-routing-resolution.sh`
- [ ] Confirm by reading the diff that Group 1's `--clean` suppression assertion and Group 2's
      presence assertions both still reference the unchanged envelope tag.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: interface

**Tier Justification**: `suite_selection_select` over this phase's two files returns exactly `test-force-phases.sh test-orchestrate-build-aux-dispatch.sh test-orchestrate-build-dispatch.sh test-orchestrate-context-growth.sh test-orchestrate-cycle-plan.sh test-orchestrate-record-decision.sh test-orchestrate-recover-message-findings.sh test-orchestrate-unwind-dispatch.sh test-routing-resolution.sh`, and `run-all.sh --only` over that list is the specific check covering every enumerated dependent of the changed call site.

**Scope Hypothesis**: This phase hypothesises that `memory-retrieve.sh` is referenced from exactly one call site in `orchestrate-build-dispatch.sh` (its line 354) and from exactly one stub-installation site plus a header comment in the test suite. Confirm at implementation time with `grep -rn 'memory-retrieve' agent-system/extensions/core/scripts/` before editing; if the grep returns a site this plan does not name, handle it in this phase rather than leaving a dangling reference.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - swap the script basename
  on the Stage 3.5 `memory_context` call line; update that block's section comment
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - rename the
  fixture stub path and update the stub comment and the suite header's stub enumeration

**Verification**:
- `grep -c 'memory-retrieve.sh' agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
  returns 0, and `grep -c 'sapience-retrieve.sh'` returns 1.
- `git diff` on the dispatch builder shows a single changed call line plus its comment — the
  `--clean` guard, `memory_arg3`, `2>/dev/null`, `|| memory_context=""`, the variable name, and
  the three positional arguments all byte-identical.
- The nine-suite `run-all.sh --only` run above exits 0, with Group 1's
  "research --clean: memory block suppressed" and Group 2's "memory block present" /
  "memory block carries stub content" assertions all passing.

---

### Phase 6: Amend the extension's design record and document the hazards [NOT STARTED]

**Goal**: The extension's own documentation describes the shipped mechanism accurately, no longer
contradicts it, and records the three hazards the dispatch names as document-don't-fix.

**Tasks**:
- [ ] Create `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
      covering: the repo-tag-in-`provenance` mechanism and why it is the only one that works;
      that `/v1/search` silently ignores `&project=` and the project surfaces are a paid team
      feature on this account, so the `project` field is not an alternative; that the MCP
      `sapience_remember` tool cannot produce a tagged write because its provenance string is
      fixed by the connector, which is why tagged writes go to `POST /ingest-kos` directly; that
      `explicit: true` is mandatory because the server's noise gate otherwise discards a note
      while returning a success-shaped response; and the two new scripts' roles and argument
      contracts.
- [ ] In the same file, record the three hazards plainly: **no delete API** (three probed routes
      all 404, so every write is permanent and the only remedy is manual removal in the web app);
      **writes through this path bypass the `auto_approve: false` review gate entirely**, which
      governs only the transcript-extraction path, so every write is permanent *and* unreviewed;
      and **the vault accumulates two differently-shaped populations**, because the
      transcript-extraction path cannot be repo-tagged and therefore keeps writing untagged
      objects that repo-filtered reads never see — stated as a documented asymmetry, explicitly
      not a bug and explicitly not something this design attempts to fix.
- [ ] Amend `agent-system/extensions/sapience/context/project/sapience/domain/subagent-orientation.md`
      (confirmed present, 72 lines). Its "The Deliberate Alternative" section, item 3, currently
      states that a Sapience equivalent of `<memory-context>` built by editing core's
      `orchestrate-build-dispatch.sh` "is exactly the second always-on injection path this
      extension's anti-goal forbids", and its surrounding sentence splits the two extensions "by
      altitude". Replace that item's reasoning with the accepted position — a single per-dispatch
      retrieval injection, repo-filtered, *replacing* rather than supplementing the local-vault
      injection — using the one sanctioned record-versioning form, a dated
      `**Amended by** <doc>, <date>:` cross-document note, and no "no longer"/"previously"/
      "superseded" phrasing. The file's first two sections (why a manifest
      `hooks.context_injection` entry is structurally unreachable for a `task_type`-less
      extension, and why post-task observers are the wrong shape) remain correct and are left
      intact.
- [ ] Add a short subsection to
      `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
      (confirmed present, 60 lines) noting that the direct `POST /ingest-kos` write path bypasses
      the same `auto_approve: false` gate its existing "Two Different Paths Into the Vault"
      section describes for the four MCP write tools, and pointing at `per-repo-scoping.md` for
      the bound that keeps unreviewed volume per completed task rather than per decision.
- [ ] Add the loading-strategy row for `domain/per-repo-scoping.md` to
      `agent-system/extensions/sapience/context/project/sapience/README.md`.
- [ ] Add the `per-repo-scoping.md` entry to
      `agent-system/extensions/sapience/index-entries.json` with `load_when: {}` and
      `on_demand: true`, matching every sibling entry, and update the `line_count` field on each
      entry whose file this phase changed (the index carries a per-entry `line_count` that goes
      stale on any edit).
- [ ] Update `agent-system/extensions/sapience/EXTENSION.md` so its context-pointer list includes
      the new domain file and its "What this extension adds" paragraph names the two scripts and
      the per-dispatch injection alongside the existing permission-grant and postflight-wrapup
      content.
- [ ] Confirm no deliverable under `agent-system/**` cites a task number, per
      `rules/no-task-references-in-deliverables.md`.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's touched paths returns the `__FULL_SWEEP__` sentinel, so no suite covers this edit and none is claimed; the honest covering check is sub-case (b)'s gate subset, `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` (the repository root — the directory holding `.claude-extensions.json` — as `TARGET`, since a source-store directory has no `.claude/` tree), run together with the `local` row's diff read-through.

**Scope Hypothesis**: This phase hypothesises that `subagent-orientation.md`'s contradiction of the shipped mechanism is confined to its "The Deliberate Alternative" section, item 3, and the altitude-split sentence that follows it. Confirm at implementation time by reading the whole file and grepping the extension's other four context files for the same anti-goal framing; if the framing recurs elsewhere, amend those occurrences in this phase too rather than leaving a partial amendment.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - new
  file: the scoping mechanism, the script contracts, and the three hazards
- `agent-system/extensions/sapience/context/project/sapience/domain/subagent-orientation.md` -
  amend item 3 of "The Deliberate Alternative" with a dated cross-document amendment note
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` -
  add the direct-write-path bypass subsection
- `agent-system/extensions/sapience/context/project/sapience/README.md` - add the new file's
  loading-strategy row
- `agent-system/extensions/sapience/index-entries.json` - add the new entry and refresh every
  stale per-entry line count
- `agent-system/extensions/sapience/EXTENSION.md` - name the two scripts, the injection path, and
  the new context pointer

**Verification**:
- `jq -e '.entries | length' agent-system/extensions/sapience/index-entries.json` reflects the
  added entry, and `jq -e '.entries[] | select(.path | endswith("per-repo-scoping.md"))'` returns
  the new entry with `on_demand: true` and `load_when: {}`.
- Each changed entry's `line_count` matches `wc -l` on its file.
- As an additional check beyond the tier (the selector maps `index-entries.json` on its own to
  these suites, even though the phase's whole path set resolves to the sentinel):
  `run-all.sh --only test-context-reachability.sh,test-deploy-orphans.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-manifest-scripts-sync.sh`
  exits 0.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 with both gates reporting checks run (not SKIP).
- `grep -rniE '\b(no longer|previously|formerly|supersed)' ` over the three changed markdown files
  returns nothing outside a dated `**Amended by**` note.
- `grep -rniE 'task [0-9]{2,}' ` over the six files returns nothing.
- Reading `subagent-orientation.md` end to end confirms it contains no remaining statement that a
  per-dispatch Sapience retrieval injection is forbidden.

---

### Phase 7: Final redeploy, end-to-end degradation checks, and the full gate set [NOT STARTED]

**Goal**: The whole change deployed and verified together: `--clean` still suppresses, an
unreachable host still yields a building dispatch with empty injection, the envelope is
shape-comparable to the one it replaces, and the complete gate set is green.

**Tasks**:
- [ ] Redeploy with the bounded-wait idiom: `timeout 540 bash .claude/scripts/deploy-headless.sh`,
      invoked through the Bash tool with its `timeout` parameter raised to 600000.
- [ ] Confirm the deployed `orchestrate-build-dispatch.sh` carries the swapped call line and that
      both deployed sapience scripts are present and executable.
- [ ] **V5 — outage degrades, never breaks.** Build a real dispatch for a scratch task with
      `SAPIENCE_HOST` pointed at an unroutable address, and confirm the dispatch file is produced,
      the builder exits 0, and the dispatch contains no `<memory-context>` block — the exact
      behavior the preserved `|| memory_context=""` wrapper provides. Confirm the elapsed time
      stays inside the script's `--max-time` bound rather than hanging.
- [ ] **V6 — `--clean` still suppresses.** Build the same dispatch with `--clean` and confirm no
      `<memory-context>` block appears, with the host reachable.
- [ ] **V7 — envelope shape comparison.** Capture `sapience-retrieve.sh`'s output and
      `memory-retrieve.sh`'s output for an equivalent corpus and diff their *structure*: identical
      open and close tags, identical preamble sentence, identical
      `### <title> (relevance: <score>)` heading form, identical blank-line separation. Only the
      per-entry content differs, so no consumer needs changing. Record the diff result.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`, and confirm it exits 0
      with Gate 8's full shell-suite battery green.
- [ ] Record the manual app.spnc.ai cleanup item for the completion summary: the two orphaned
      probe KOs (`806180dc43c5cb34`, `9ba2b479b5e4a7e2`) plus any permanent KO Phase 4's V2 wrote,
      all unremovable via API.
- [ ] Record issue-log entries for anything that arose during the task and was not already logged.

**Timing**: 1.5 hours

**Depends on**: 5, 6

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree
- (no source-store file is edited in this phase)

**Verification**:
- `deploy-headless.sh` exits 0 within the 540s bound, and the deploy-freshness notice for `core`
  is cleared.
- V5: the dispatch builder exits 0 against an unroutable host, the dispatch file exists, and it
  contains no `<memory-context>` block.
- V6: `--clean` produces a dispatch with no `<memory-context>` block.
- V7: the two envelopes differ only in per-entry content, not in tags, preamble, heading form, or
  separation.
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set, including gate 3
  (doc-lint), gate 4 (task-reference lint), and Gate 8's full suite battery, with no `--skip-slow`
  and no `--only-gate` narrowing.

---

## Testing & Validation

- [ ] `shellcheck` clean on both new scripts.
- [ ] A repo-tagged, `explicit: true` write reports `written >= 1`; a repo-filtered read returns
      it; a read filtered to a different repo tag does not.
- [ ] A response carrying `gated >= 1` makes `sapience-remember.sh` exit non-zero and name the
      triggering field, with nothing permanent written.
- [ ] A `set_aside` response is treated the same way, not swallowed.
- [ ] With the retrieval endpoint unreachable, a dispatch still builds and runs with an empty
      `memory_context`, inside the script's timeout bound.
- [ ] `--clean` still suppresses injection after the swap.
- [ ] The emitted `<memory-context>` block is shape-comparable to `memory-retrieve.sh`'s for an
      equivalent corpus, so no consumer needs changing.
- [ ] `sync-manifest-scripts.sh --check` exits 0.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 with no narrowing flags.
- [ ] No deliverable under `agent-system/**` cites a task number or carries record-versioning
      language outside a dated `**Amended by**` note.

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` (new)
- `agent-system/extensions/sapience/scripts/sapience-remember.sh` (new)
- `agent-system/extensions/sapience/manifest.json` (`provides.scripts` populated)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (call site swapped)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` (fixture stub
  renamed)
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` (new)
- `agent-system/extensions/sapience/context/project/sapience/domain/subagent-orientation.md`
  (amended)
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
  (amended)
- `agent-system/extensions/sapience/context/project/sapience/README.md`,
  `index-entries.json`, `EXTENSION.md` (updated)
- A regenerated deployed `.claude/` tree (gitignored deploy artifact, not a committed output)
- **Manual cleanup item for the completion summary**: KO hashes `806180dc43c5cb34` and
  `9ba2b479b5e4a7e2`, plus any permanent KO written during Phase 4's V2, all require manual
  removal at app.spnc.ai because no delete API exists.

## Rollback/Contingency

- **Code**: every phase's edits are confined to tracked files under `agent-system/extensions/`,
  so `git revert` of the task's commits followed by
  `timeout 540 bash .claude/scripts/deploy-headless.sh` restores the prior state completely. The
  deployed `.claude/` tree is a disposable artifact regenerated from the source store, so nothing
  there needs hand-restoring.
- **The call-site swap specifically** is a one-line change, revertible on its own: restoring the
  `memory-retrieve.sh` basename (and the fixture stub path) returns the dispatch builder to
  local-vault injection without touching anything else. `memory-retrieve.sh` and `.memory/` are
  deliberately left in place by this task, so that fallback stays available until a separate
  record retires them.
- **If a phase closes red**, mark it `[PARTIAL]` and stop rather than proceeding: Phases 5 and 6
  both depend on Phase 3's manifest declaration, and Phase 5's swap depends on Phase 4 having put
  the script in the deployed tree. Phase ordering was chosen specifically so the window in which
  the call site could reference a missing deployed script never opens.
- **Writes cannot be rolled back.** There is no delete API, so any KO written during verification
  is permanent. This is why Phase 4's V2 writes exactly one genuinely useful note rather than a
  probe, why V4's gated write is designed to leave nothing behind, and why the hashes are handed
  to the summary as a manual cleanup item instead of a scripted undo.
