# Research Report: Task #496

**Task**: 496 - Add per-repo storage and injection to the sapience extension
**Started**: 2026-11-10T00:00:00Z
**Completed**: 2026-11-10T00:00:00Z
**Effort**: Medium (2 new scripts, 1 edit to a shared core script, manifest/doc updates)
**Dependencies**: Shared-file-territory edges on `orchestrate-build-dispatch.sh` with 360, 449, 450, 487 (all `[completed]`, so the edges are inert for sequencing purposes but the file remains shared territory); documentation edge with 488 (`[completed]`, owns `settings-fragment.json` and `review-gate-boundary.md`)
**Sources/Inputs**: Codebase (`agent-system/extensions/sapience/**`, `agent-system/extensions/core/scripts/memory-retrieve.sh`, `orchestrate-build-dispatch.sh`), `~/.sapience/mcp.py` (vendor MCP server source), `~/.sapience/config.json` (local auth/host config, token redacted), `~/.dotfiles/docs/sapience.md`, `specs/state.json` (batch context: 497 completed, 498 hold, 499 not_started)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch already carries the hard empirical findings (scoping mechanism, API quirks,
  latency, noise-gate behavior) from prior live-host research; this report's job is to ground
  those findings in the actual codebase paths/line numbers and surface implementation-shaping
  details the dispatch does not spell out: the exact auth mechanism (`token=` query param, not
  a Bearer header, for `/v1/search` and `/ingest-kos`), the KO object shape `/ingest-kos` expects,
  and the extension's current `provides.scripts: []` / no `scripts/` directory (both new scripts
  are greenfield additions, not edits).
- **Direct tension with existing design doc**: `context/project/sapience/domain/subagent-orientation.md`
  (written for a prior task in this same extension) argues at length that a per-dispatch Sapience
  retrieval injection is "exactly the second always-on injection path this extension's anti-goal
  forbids" and settles on "no second per-dispatch retrieval injection" as the deliberate
  resolution. Task 496 directly supersedes that resolution by design (it is the stated purpose of
  the batch: replace the memory extension's local-vault substrate with Sapience). The plan phase
  must treat this document as requiring an update, not as settled background a new retrieval path
  can coexist with silently.
- Auth for both new HTTP calls is a `token=<SAPIENCE_TOKEN>` query-string parameter (identical for
  GET and POST), read with `SAPIENCE_TOKEN` env var first, falling back to `~/.sapience/config.json`'s
  `"token"` field, with `"host"` (`https://app.spnc.ai`) as the base URL — the exact precedence
  `mcp.py` itself uses (`os.environ.get('SAPIENCE_TOKEN') or _CFG.get('token')`).
- The `/ingest-kos` body shape, confirmed from `mcp.py`'s own `sapience_remember` call site, is
  `{"token": <token>, "kos": [{"subject", "predicate", "object_value", "ko_type", "confidence",
  "provenance", "explicit"?, "source_loc"?}], "source": "<tag>"}`. The dispatch's required
  `provenance` repo-tag and mandatory `explicit: true` both land as fields of the single KO object
  inside `kos[0]`, not as sibling top-level body fields.
- Recommended approach: two new bash scripts (`sapience-retrieve.sh`, `sapience-remember.sh`)
  under a new `agent-system/extensions/sapience/scripts/` directory, declared in
  `manifest.json`'s `provides.scripts` (currently `[]`) so `sync-manifest-scripts.sh` deploys them
  to `.claude/scripts/`; a one-line swap in `orchestrate-build-dispatch.sh`'s existing
  `memory_context` block preserving its exact failure-swallowing and `--clean` guard shape; and
  updates to `subagent-orientation.md` plus a new hazards section (no-delete, unreviewed-write,
  two-population asymmetry) folded into `review-gate-boundary.md` or a new domain file.

## Context & Scope

Task 496 is the first of a four-task batch (496, 497 completed, 498 on hold, 499 not_started)
migrating durable cross-session knowledge storage from the local `.memory/` vault (memory
extension) to the hosted Sapience vault. This task is the dependency root: it must land before
499 ("retire the memory extension") can proceed, because 499 needs a working Sapience-backed
replacement for `memory-retrieve.sh`'s injection role before the memory extension's substrate can
be removed.

The dispatch instructs editing only `agent-system/extensions/sapience/**` and
`agent-system/extensions/core/**` (the source store), never the deployed `.claude/**` tree, per
`rules/source-store-deploy-boundary.md`, followed by a `deploy-headless.sh` redeploy. This report
focuses on: (1) grounding the three deliverables (retrieve script, dispatch swap, remember script)
in the real call sites and data shapes involved, (2) surfacing additional codebase facts the
dispatch's prior research (done against the live host, not the codebase) did not need to capture,
and (3) flagging the direct conflict with `subagent-orientation.md`'s existing anti-goal language
so the plan phase does not have to rediscover it mid-implementation.

Scope explicitly excludes: re-verifying the already-settled live-host findings (repo-tag-in-
`provenance` scoping, `project=` dead end, noise-gate `explicit: true` requirement, no-delete API,
0.22s latency) — the dispatch states these were empirically measured and marks them as not to be
re-derived.

## Findings

### Codebase Patterns

**`memory-retrieve.sh` (`agent-system/extensions/core/scripts/memory-retrieve.sh`, 181 lines)** —
the script `sapience-retrieve.sh` must emit a byte-comparable `<memory-context>` envelope for.
Structure to replicate at the output layer:
- Two-phase design: Phase 1 keyword extraction + local scoring, Phase 2 selection within budget
  then content formatting. The dispatch directs reusing *only* the keyword-extraction stage
  (lines 52-72: lowercase, `tr -cs '[:alpha:]' '\n'`, stop-word grep, `awk 'length > 3'`, dedupe,
  `head -10`) — the scoring/selection stages (lines 74-135) are local-index-specific and have no
  equivalent once the corpus lookup moves server-side (the server's own `/v1/search` ranking
  replaces local keyword-overlap scoring).
- Output format (lines 138-158): literal `<memory-context>` / `</memory-context>` wrapper, one
  `### {title} (relevance: {score})` heading per entry, then raw file content, blank line between
  entries. For Sapience, "title" and "content" must be synthesized per search hit from the KO's
  `subject`/`predicate`/`object_value` fields (and optionally `provenance`) rather than read from
  a local file — there is no local file per hit.
- Hard limits stated in the header comment and enforced in code: `TOKEN_BUDGET=2000`,
  `MAX_ENTRIES=5`. The dispatch requires preserving both numbers for the new script, and the
  endpoint call itself already caps at `limit=5` server-side, so the entry cap is naturally
  satisfied by the request; the token budget still needs a client-side truncation pass since
  `/v1/search` has no equivalent "stop after N tokens" parameter.
- Sourcing/path pattern every core script in this family follows: `SCRIPT_DIR` bootstrap,
  `source "${SCRIPT_DIR}/lib/common.sh"`, `common_repo_root "$SCRIPT_DIR" 2`, and a
  `deploy-root-guard.sh` source-and-exit-on-failure line (lines 36-39). `sapience-retrieve.sh`
  should follow this same bootstrap, with `PROJECT_ROOT` used only to derive the repo slug (via
  `basename "$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel)"`, per the dispatch's instruction)
  rather than to locate `.memory/memory-index.json` (there is no local index to open).
- Exit-code contract: exit 1 with empty stdout on any failure/no-match path (missing index,
  no keywords, no entries after scoring, no file readable); exit 0 with the full envelope on
  success. `sapience-retrieve.sh` must honor the same contract so the dispatch-side
  `2>/dev/null || memory_context=""` wrapper continues to work unmodified in spirit (the dispatch
  deliverable renames the variable/script but keeps the shape).

**`orchestrate-build-dispatch.sh` Stage 3.5 memory_context block** (lines 349-355 of
`agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`):
```bash
memory_context=""
if [ "$clean_flag" != "true" ]; then
  memory_arg3=""
  [ "$phase" = "research" ] && memory_arg3="$focus_prompt"
  memory_context=$(bash "${SKILL_REPO_ROOT}/.claude/scripts/memory-retrieve.sh" "$description" "$task_type" "$memory_arg3" 2>/dev/null) || memory_context=""
fi
```
This is the exact and only call site named in the dispatch. Two details worth flagging for the
plan:
1. The script is invoked at its **deployed** path (`${SKILL_REPO_ROOT}/.claude/scripts/...`), not
   the source-store path — `orchestrate-build-dispatch.sh` itself runs from the deployed tree at
   dispatch-build time. This means the new script must be declared in the sapience extension's
   manifest `provides.scripts` so `sync-manifest-scripts.sh` actually places
   `sapience-retrieve.sh` at `.claude/scripts/sapience-retrieve.sh` on redeploy — simply adding
   the file under `agent-system/extensions/sapience/scripts/` without the manifest declaration
   would leave the deployed call site unable to find it.
2. `memory_context` is read at line 831-832 (`if [ -n "$memory_context" ]; then echo "$memory_context"`)
   — a plain string-emptiness check, so whatever variable name the swapped call assigns into
   (the dispatch does not mandate renaming the variable, only the call target) must still satisfy
   that same consumer check. The simplest compliant edit keeps the variable name `memory_context`
   and only changes the script path and arguments on the right-hand side, minimizing blast radius
   on this shared-territory file.

**Sapience extension's current shape** (`agent-system/extensions/sapience/`): `manifest.json`
declares `"provides": {"scripts": [], ...}` and `"routing_exempt": true`, with no `task_type`
field at all (confirmed by `subagent-orientation.md`'s own citation of this fact to explain why a
`hooks.context_injection` entry would be unreachable). There is currently no `scripts/`
subdirectory under the extension at all — contrast with the memory extension, which has
`agent-system/extensions/memory/scripts/` holding four `bootstrap-harvest*.sh` scripts declared in
its own `provides.scripts` array. The two new scripts for this task are a greenfield addition
following that same `extensions/{name}/scripts/` + `provides.scripts` + `sync-manifest-scripts.sh`
pattern, not an edit to an existing file.

**Auth and endpoint mechanics, extracted from `~/.sapience/mcp.py`** (the vendor's own MCP server
source, read for grounding, not a file this task edits):
- `HOST = (os.environ.get('SAPIENCE_HOST') or _CFG.get('host') or 'https://app.spnc.ai').rstrip('/')`
  and `TOKEN = os.environ.get('SAPIENCE_TOKEN') or _CFG.get('token') or ''`, where `_CFG` is
  `json.load(open('~/.sapience/config.json'))`. On this machine, `config.json` carries
  `"host": "https://app.spnc.ai"` and a `"token"` field (value not reproduced here). The new
  scripts should resolve credentials with the identical precedence: `SAPIENCE_TOKEN` env var,
  else `~/.sapience/config.json`'s `.token`, and `SAPIENCE_HOST` env var else `.host` else the
  `https://app.spnc.ai` literal default.
- The `api()` helper's URL construction is the authoritative auth shape for **every** endpoint it
  calls, including both `/v1/search` (GET) and `/ingest-kos` (POST):
  `url = HOST + path + ('&' if '?' in path else '?') + 'token=' + urlencode(token)`. Authentication
  is a `token=` query-string parameter appended to the URL — not an `Authorization: Bearer` header
  (that header pattern exists elsewhere in `mcp.py` only for an unrelated endpoint,
  `/v1/effects/block`, and does not apply to search or ingest). A `curl`-based script should
  construct `"$HOST$path&token=$TOKEN"` (or `?token=` when the path carries no existing query
  string), plus a `content-type: application/json` header for POST bodies and (matching `mcp.py`'s
  own convention) an `X-Sapience-Client` header identifying the caller, e.g.
  `X-Sapience-Client: claude-code-nvim-dispatch` or similar.
- `/v1/search`'s real call shape (`mcp.py`'s `sapience_search` tool, confirmed working code):
  `path = '/v1/search?q=' + quote(query) + '&limit=8'`, with `&source=' + quote(src)` appended
  only when a source filter is requested. This matches the dispatch's own empirically-derived
  `GET /v1/search?q=<keywords>&source=[repo:<slug>]&limit=5` call shape exactly (limit differs
  only because the dispatch specifies 5, matching `MAX_ENTRIES`).
- `/ingest-kos`'s real body shape (`mcp.py`'s `sapience_remember` tool, confirmed working code):
  ```json
  {"token": "<token>", "kos": [{
    "subject": "...", "predicate": "finding is", "object_value": "...",
    "ko_type": "insight", "confidence": 0.8,
    "provenance": "<repo-tag + description>",
    "explicit": true,
    "source_loc": "..."
  }], "source": "mcp-live"}
  ```
  The dispatch's two mandatory fields — the repo-tagged `provenance` string (e.g. embedding
  `[repo:nvim]`) and `explicit: true` — are both fields *inside the KO object* (`kos[0]`), not
  top-level body fields. `sapience-remember.sh` must build its JSON payload with that nesting.
- The gated/silent-loss response shape the dispatch calls out (`{"ok": true, "written": 0,
  "gated": 1}`) matches `mcp.py`'s own defensive handling at the `sapience_remember` call site,
  which explicitly checks `if r.get('gated'):` and surfaces a distinct message rather than
  treating the call as successful — i.e. the vendor's own client code already treats `gated` as a
  condition requiring special handling, confirming the dispatch's instruction that
  `sapience-remember.sh` must do the same (report `gated >= 1` as a loud failure) is consistent
  with, not a departure from, how the vendor's own first-party client behaves.

### External Resources

- `~/.dotfiles/docs/sapience.md` (machine configuration, not part of this repo) documents the
  token/host storage location (`~/.sapience/config.json`, mode 600) and confirms this machine's
  capture-project entry for this very repo is named `"nvim"` (`path_prefix:
  /home/benjamin/.config/nvim`, `name: "nvim"`) — consistent with the dispatch's repo-slug
  derivation via `git rev-parse --show-toplevel` basename (`nvim`), though that capture-project
  mechanism is a *different* system (the transcript-extraction path's project tagging) from the
  `provenance`-string repo tag this task implements; the two should not be conflated in the
  implementation even though they happen to agree on the slug for this repo.
- No existing shell-script precedent in this codebase calls a Sapience HTTP endpoint directly
  (the zulip extension's API calls, the closest analog for "a skill-level HTTP integration," are
  invoked inline from `SKILL.md` rather than via a dedicated script, so there is no reusable
  curl-wrapper library to lift from for error handling/retry conventions — the new scripts are
  original work, not an adaptation of an existing pattern).

## Recommendations

- Create `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` and
  `agent-system/extensions/sapience/scripts/sapience-remember.sh`, declare both in
  `manifest.json`'s `provides.scripts` array (currently `[]`), so `sync-manifest-scripts.sh`
  deploys them to `.claude/scripts/` on the mandatory post-edit `deploy-headless.sh` run — without
  this manifest change the dispatch-swapped call site in `orchestrate-build-dispatch.sh` would
  reference a file that never lands in the deployed tree.
- `sapience-retrieve.sh` argument contract should mirror `memory-retrieve.sh`'s exactly
  (`<description> <task_type> [focus_prompt]`) so the one-line dispatch-swap edit changes only the
  script path, not the call's argument list or count.
- Build the `/v1/search` request as `GET "${HOST}/v1/search?q=$(urlencode "$keywords")&source=$(urlencode "[repo:${slug}]")&limit=5&token=${TOKEN}"` via `curl -sS --max-time <N>`, reusing the
  keyword-extraction block verbatim (lines 58-68 of `memory-retrieve.sh`) rather than reimplementing
  it, per the dispatch's explicit instruction.
- Client-side token-budget truncation (the `2000`-token cap that `/v1/search`'s own `limit=5`
  cannot enforce) can reuse the same rough `token_count` heuristic `memory-retrieve.sh` applies to
  local files (word/char-based estimate) against each hit's synthesized title+body text, accumulating
  into the same greedy-selection shape (lines 121-131) the existing script already uses, so the two
  budget enforcements stay behaviorally identical even though the corpus differs.
- `sapience-remember.sh` should accept structured arguments (subject/predicate/value or a single
  freeform note plus repo context) and construct the KO exactly in the shape shown above, defaulting
  `ko_type` and `confidence` to the same values `mcp.py`'s own `sapience_remember` tool uses
  (`"insight"`, `0.8`) unless the plan phase decides a task-boundary write script warrants a
  different default — document whichever is chosen rather than leaving it implicit.
- Because there is no delete API (dispatch-confirmed: three delete routes all 404), the plan phase
  should bound `sapience-remember.sh`'s call sites to task-boundary postflight (mirroring the
  existing `sapience_wrapup` 3-8-notes-per-task-completion pattern already documented in
  `EXTENSION.md`), not a per-decision or per-phase call site — consistent with the dispatch's own
  "prefer few, high-value, well-formed writes at a task boundary" instruction.
- Update `context/project/sapience/domain/subagent-orientation.md` as part of this task's
  documentation deliverable: its current text states flatly that building a per-dispatch Sapience
  retrieval the way `<memory-context>` works "is exactly the second always-on injection path this
  extension's anti-goal forbids." Task 496 does precisely that. Leaving the file unedited would
  leave a direct, citable self-contradiction in the extension's own design record once this task
  lands; the plan should either revise that file's reasoning to reflect the batch's new intent
  (replacing, not supplementing, the memory extension's injection role) or explicitly supersede its
  stated anti-goal with a dated rationale, per `no-record-versioning-in-deliverables.md`'s
  amendment-note exception (a real change to an accepted decision, not draft-lineage language).
- Fold the dispatch's named hazards (no-delete API, unreviewed-write bypass of `auto_approve`,
  the two-population asymmetry between tagged live writes and untagged transcript-extraction
  writes) into the extension's documentation — either as a new domain file (e.g.
  `domain/per-repo-injection-hazards.md`) or as additions to the existing `review-gate-boundary.md`,
  which already documents the review-gate-bypass point for the four MCP write tools and is the
  natural home for the parallel point about the new direct-`/ingest-kos` write path also bypassing
  that gate.
- Record the two orphaned probe KOs (hashes `806180dc43c5cb34`, `9ba2b479b5e4a7e2`) as a manual
  cleanup item in the task's completion summary rather than as implementation work — there is no
  script-level action that can address them given the confirmed absence of a delete API.

## Decisions

- The repo-tag-in-`provenance` scoping mechanism, the `project=`-field dead end, and the
  `sapience_remember` MCP tool's unsuitability for tagged writes are treated as settled per the
  dispatch's explicit instruction not to re-derive them; this report does not re-test them.
- The auth mechanism for the two new HTTP calls is a `token=` query-string parameter (not a
  Bearer header), confirmed by reading `mcp.py`'s `api()` helper, which is the single code path
  both `/v1/search` and `/ingest-kos` calls go through in the vendor's own first-party client.
- The two new scripts are placed under a new `agent-system/extensions/sapience/scripts/`
  directory and declared via `manifest.json`'s `provides.scripts`, following the memory
  extension's existing precedent rather than inventing a new deployment mechanism.
- The dispatch-swap edit targets `orchestrate-build-dispatch.sh` lines 349-355 specifically, and
  should keep the `memory_context` variable name to avoid touching the unrelated consumer check at
  lines 831-832, minimizing the edit's footprint on this shared-territory file.

## Risks & Mitigations

- **No delete API** (dispatch-confirmed, re-flagged here as a risk the plan must design against):
  every `sapience-remember.sh` call is permanent. Mitigation: restrict call sites to task-boundary
  postflight with a small, bounded note count (3-8, mirroring the existing `sapience_wrapup`
  convention), never a per-phase or per-decision call.
- **Network outage during dispatch-build**: the swapped retrieval call is a network round-trip
  replacing a local jq pass, so a Sapience outage could, if mishandled, break every dispatch in a
  batch. Mitigation: preserve the exact `2>/dev/null) || memory_context=""` failure-swallowing
  shape at the call site — this is explicitly re-stated as a verification criterion in the
  dispatch and is the single most important behavioral invariant to test before/after the swap.
- **Documentation self-contradiction**: `subagent-orientation.md` currently argues against the
  exact mechanism this task builds. Mitigation: treat updating that file as part of this task's
  documentation deliverable (see Recommendations), not a follow-up.
- **Two differently-shaped vault populations** (tagged live writes vs. untagged transcript
  extraction): dispatch-confirmed and explicitly scoped as "document, don't fix." Mitigation:
  state this plainly in whichever documentation file covers the new write/read paths, so a future
  reader does not mistake the untagged population for a bug.
- **Credential handling in a new script**: `sapience-retrieve.sh`/`sapience-remember.sh` read a
  live secret (`~/.sapience/config.json`'s `.token`, mode 600) outside the Nix store. Mitigation:
  mirror `mcp.py`'s own read-only, in-memory-only handling (read once per invocation, never log or
  echo the token, never write it to a temp file) — the existing vendor code is itself a safe
  precedent to follow here.

## Context Extension Recommendations

- **Topic**: curl/HTTP-client conventions for extension scripts calling an external API with a
  query-param token.
- **Gap**: this codebase currently has no reusable shell helper (akin to `common.sh`) for making
  an authenticated HTTP call with consistent timeout, retry, and error-surfacing conventions —
  each integration (zulip inline, now sapience) reinvents this.
- **Recommendation**: after this task and its sibling batch items land, consider whether a shared
  `scripts/lib/http-client-common.sh` (timeout defaults, JSON body construction, non-2xx handling)
  would reduce duplication across the zulip and sapience integrations — not a blocker for this
  task, but worth a future context/tooling note if a third such integration appears.

## Appendix

- Search queries used: none (web search); this research was entirely codebase-exploration plus
  direct reading of `~/.sapience/mcp.py` and `~/.sapience/config.json` on the local machine (not
  web sources).
- Files read: `agent-system/extensions/core/scripts/memory-retrieve.sh` (full, 181 lines),
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (lines 340-380, 820-840 via
  grep+read), `agent-system/extensions/sapience/manifest.json`, `settings-fragment.json`,
  `EXTENSION.md`, `index-entries.json`, all four `context/project/sapience/domain/*.md` files,
  `agent-system/extensions/memory/manifest.json` (for the `provides.scripts` precedent),
  `~/.dotfiles/docs/sapience.md` (lines 1-150), `~/.sapience/mcp.py` (targeted greps and reads:
  lines 1-200, 1460-1535), `~/.sapience/config.json` (read with secrets programmatically redacted
  before this report's drafting — no token value appears anywhere in this report or was retained
  in any intermediate artifact), `specs/state.json` (batch context for tasks 496-499).
- Dependency/territory context: `orchestrate-build-dispatch.sh` is shared territory with 360, 449,
  450, 487 (all `[completed]` per `specs/state.json`); documentation territory shared with 488
  (`[completed]`, owns `settings-fragment.json` and `review-gate-boundary.md`).
