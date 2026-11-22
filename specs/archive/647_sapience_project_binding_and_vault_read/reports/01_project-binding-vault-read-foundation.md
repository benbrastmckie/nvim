# Research Report: Task #647

**Task**: 647 - Bind a repo to a Sapience project and read the vault's shared state
**Started**: 2026-11-19T08:00:00Z
**Completed**: 2026-11-19T08:25:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/sapience/**), /home/benjamin/Projects/Sapience/sapience-app/{brain_server.py,repo_link.py}, ~/.sapience/{mcp.py,config.json}, specs/TODO.md (sibling tasks 648/649), dispatch file
**Artifacts**: - specs/647_sapience_project_binding_and_vault_read/reports/01_project-binding-vault-read-foundation.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Every mechanism the dispatch cites was independently re-verified against the live source files
  on this machine (`repo_link.py`, `brain_server.py`'s `_people_project_share` and
  `project_split_confirmed`, `~/.sapience/mcp.py`'s credential precedence) and all match the
  dispatch's description exactly — no corrections needed to the dispatch's technical claims.
- The extension has no `scripts/lib/` today; `scripts/lib/sapience-api-lib.sh` is a genuinely new
  directory, and introducing it is a deliberate reversal of a documented prior decision
  (`sapience-remember.sh`'s own header: "deliberately COPIED... not shared via a scripts/lib/
  helper -- a shared helper would add a path outside this task's declared file_scope"). That
  constraint no longer applies here because this task's own `file_scope` names the lib directly.
- The marker-delimited `sapience-worktree-checkout-resolution` block is currently duplicated,
  byte-identical, across exactly five files, and `test-sapience-mcp-registration.sh`'s Case 30
  hardcodes that list of five paths. Adding the block to the two new top-level scripts
  (`sapience-project-bind.sh`, `sapience-vault-read.sh`) — following the existing convention of
  each *consumer* carrying its own copy rather than sourcing it from a lib — will silently leave
  Case 30 blind to the two new copies unless the implementer also extends `LOCKSTEP_FILES` in
  that test. This is a plan-phase action item, not merely an observation.
- Deploy flattens every extension's `scripts/` tree into `.claude/scripts/` and every extension's
  `scripts/lib/` into one shared `.claude/scripts/lib/`, alongside core's `common.sh` and
  `deploy-root-guard.sh`. `sapience-api-lib.sh` will not collide with anything there; no other
  extension owns that filename.
- Recommended approach: build the shared lib first (host/token resolution, POST/GET helpers),
  then the two scripts on top of it, each carrying its own copy of the worktree-resolution block
  (not sourced from the lib) to preserve the existing "byte-identical across every copy" test
  contract, with `test-sapience-mcp-registration.sh` extended to watch both new copies.

## Context & Scope

Task 647 is the first of a three-task dependency chain (647 -> 648 -> 649) building toward a
`/sapience` command. It owns exactly three new scripts and two new test files, all under the
source store at `agent-system/extensions/sapience/` (confirmed as `.extensions.sapience.source_dir`
in `.claude-extensions.json`, and present on disk):

- `scripts/lib/sapience-api-lib.sh` (new) — shared credential/host resolution plus one
  authenticated-POST and one authenticated-GET helper.
- `scripts/sapience-project-bind.sh` (new) — interactive, confirm-or-refuse creation of a fresh
  Sapience project and persistence of the binding to `.sapience/project.json`.
- `scripts/sapience-vault-read.sh` (new) — read-only aggregation of local + vault state for a
  future draft-assembly consumer (task 649).
- `scripts/tests/test-sapience-project-bind.sh`, `scripts/tests/test-sapience-vault-read.sh` (new).

This research pass re-verified the dispatch's technical claims against primary sources rather
than re-deriving them from scratch, since the dispatch states they were already verified live
against the vault during the investigation that produced the task breakdown. The scope here is:
confirm those claims against the readable source files on this machine, map the existing
extension's conventions precisely enough that an implementer does not need to rediscover them,
and surface any tension between this task's new shared-lib approach and the extension's prior
per-script-duplication precedent.

## Findings

### Codebase Patterns

**Extension layout and existing scripts** (`agent-system/extensions/sapience/`):
```
context/, EXTENSION.md, hooks/, index-entries.json, manifest.json, README.md, rules/,
scripts/{install-sapience-mcp-session-hook.sh, postflight-sapience-notes.sh,
         sapience-remember.sh, sapience-retrieve.sh, setup-sapience-mcp.sh,
         verify-sapience-context-scoping.sh, verify-sapience-mcp.sh,
         tests/{test-postflight-sapience-notes.sh, test-sapience-capture.sh,
                test-sapience-context-scoping.sh, test-sapience-mcp-registration.sh}}
```
There is **no `scripts/lib/` directory** under the sapience extension today — every existing
script sources the shared `lib/common.sh` and `deploy-root-guard.sh` that live one level up, in
core's own `scripts/` tree (`agent-system/extensions/core/scripts/lib/common.sh` and
`agent-system/extensions/core/scripts/deploy-root-guard.sh`), which deploy to
`.claude/scripts/lib/common.sh` and `.claude/scripts/deploy-root-guard.sh` respectively. Deploy
flattens every extension's own `scripts/` subtree into that same `.claude/scripts/` directory
(confirmed via `.claude-extensions.json`'s `installed_files` list for sapience, which lists every
script at `.claude/scripts/<name>.sh`, not under a per-extension subdirectory), and every
extension's own `scripts/lib/` entries land in the one shared `.claude/scripts/lib/` directory
(confirmed by grepping core's `deploy-headless.sh`/`verify-deploy.sh`/`orchestrate-batch-admit.sh`
comments, which all refer to a single `.claude/scripts/lib/` target regardless of which
extension's source tree a given lib file came from). `sapience-api-lib.sh` is therefore safe to
add: no existing extension owns that filename, and it will sit alongside `common.sh` and other
libs without collision.

**Credential/host resolution — confirmed byte-for-byte against the installed client.**
`~/.sapience/mcp.py` line 43-44:
```python
DEFAULT_HOST = 'https://app.spnc.ai'
HOST  = (os.environ.get('SAPIENCE_HOST') or _CFG.get('host') or DEFAULT_HOST).rstrip('/')
TOKEN = os.environ.get('SAPIENCE_TOKEN') or _CFG.get('token') or ''
```
`sapience-remember.sh` and `sapience-retrieve.sh` already each duplicate this exact precedence in
bash (reading `~/.sapience/config.json` via `jq -r '.host // empty'` / `.token // empty'`,
falling back to the `https://app.spnc.ai` literal). `scripts/lib/sapience-api-lib.sh` should
provide this resolution once, as the dispatch requires, and both new scripts (and, per the
sibling task 648's description, the future `sapience-publish.sh`) should source it rather than
re-deriving it a third and fourth time.

**A documented precedent against sharing this exact logic — now superseded by this task's own
file_scope.** `sapience-remember.sh`'s own header is explicit that the duplication between it and
`sapience-retrieve.sh` is deliberate, not an oversight: *"The host/token/slug resolution block
below is deliberately COPIED from sapience-retrieve.sh, not shared via a scripts/lib/ helper -- a
shared helper would add a path outside this task's declared file_scope."* That reasoning was
scoped to the task that wrote `sapience-remember.sh`, whose `file_scope` did not include a new
lib directory. Task 647's `file_scope` explicitly names `scripts/lib/sapience-api-lib.sh`, so the
constraint that produced the prior duplication does not apply here — this task is exactly the
sanctioned place to introduce the shared helper the earlier header anticipated. The plan and
implementation should note this origin so a future reader does not mistake the new lib as
contradicting the older comment; it resolves it.

**Loud-failure discipline (`sapience-remember.sh`, lines 239-266).** The pattern to reuse for any
write-call-site in this task's scope (none in Deliverable 2/3 directly write KOs, but
`sapience-project-bind.sh`'s project-creation POST must apply the same discipline to its own
response shape) is: check `set_aside` (non-empty array) first, then `gated` (`!= 0`/`null`), then
`written` (`== 0`/`null`/empty), then `ok` (`!= "true"`) — all four checked unconditionally
regardless of which fires first, each producing a distinct `stderr` message naming the triggering
field, with exit code 2 reserved for a genuine server-reported failure shape (distinct from exit 1
for argument/transport errors). `_people_project_share`'s own success shape is `{'ok': True,
'project': proj, 'to': [...]}` (confirmed at `brain_server.py:58013` and the surrounding handler);
the equivalent failure-shape discipline for `sapience-project-bind.sh` is to treat an empty `to`
array, a non-2xx status, or a response lacking `ok: true` as loud failures, mirroring the same
posture even though the response fields differ from `/ingest-kos`.

**The marker-delimited worktree-resolution block and its test coverage.** The identical
`# === BEGIN sapience-worktree-checkout-resolution ... # === END ... ===` block (confirmed
present, byte-for-byte per its own claim, in `sapience-remember.sh` and `sapience-retrieve.sh`;
the dispatch and the block's own comment additionally name
`install-sapience-mcp-session-hook.sh`'s hook copy, `verify-sapience-mcp.sh`, and
`verify-sapience-context-scoping.sh` as the other three) resolves a directory to its git
toplevel, following a linked worktree to its parent checkout. `test-sapience-mcp-registration.sh`
Case 30 (lines 1215-1248) hardcodes exactly these five paths into a `LOCKSTEP_FILES` array and
`diff`s the extracted block across all five, failing loudly if any copy diverges or is missing.
**This array is not self-discovering** — it is a fixed list of five file paths, so adding the
same block to two more files (`sapience-project-bind.sh`, `sapience-vault-read.sh`, if either
needs repo-root resolution per the dispatch's Hard Constraint 3) will NOT be caught by Case 30
unless the implementer explicitly appends the two new paths to `LOCKSTEP_FILES`. Skipping that
update would leave the new copies silently uncovered by the one mechanical safeguard this
pattern already has.

**Sapience write-path rule (`agent-system/extensions/sapience/rules/sapience-write-path.md`,
confirmed present and deployed to `.claude/rules/sapience-write-path.md`).** Advisory, not
mechanized — enforced by inspection, not a lint or hook — but states the exact prohibition the
dispatch's Hard Constraint 1 restates: no instruction surface under
`agent-system/extensions/sapience/**` or `.claude/context/project/sapience/**` may name an MCP
write tool as a prescribed write path; every prescribed write goes through a script's direct
authenticated POST. The rule explicitly distinguishes *discussing* a tool (permitted, at two
named sites) from *prescribing* it (forbidden everywhere else). Neither new script in this task
writes a KO directly (that is task 648's `sapience-publish.sh`), but `sapience-project-bind.sh`'s
project-creation call is itself an authenticated POST outside the MCP surface, consistent with
the rule, and no docstring/comment in either new script should suggest `sapience_remember` or any
of the other three MCP write tools as an alternative.

**Settings-fragment grant (`settings-fragment.json`, confirmed).** Exactly the seven read-shaped
tools are granted at this repo's project scope: `sapience`, `sapience_search`,
`sapience_briefing`, `sapience_context`, `sapience_ask`, `sapience_outstanding`,
`sapience_papers` — matching the dispatch's "seven granted read-shaped MCP tools" reference for
Deliverable 3 exactly, and matching `.claude-extensions.json`'s live `merged_sections`.

**`repo_link.py` — confirmed exact validation shape** (file read in full):
- `LINK_REL = '.sapience/project.json'`.
- `REPO_NAME_RE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')`.
- `_SECRET_KEY_RE = re.compile(r'(token|key|secret|password)', re.IGNORECASE)` — `parse_link`
  returns `None` if **any** key in the dict matches this regex, not just the three named keys, so
  the written file must carry exactly `project`/`name`/`repo` and nothing else, matching the
  dispatch's "exactly three string keys" requirement precisely.
- `parse_link` also rejects a non-string `cid`/`name`/`repo`, an empty `cid`, a `repo` failing
  `valid_repo_name` (the regex above, plus explicit `/`- and `..`-rejection), or a `repo` that
  `_looks_path` (contains `/`, `\`, or starts with `.`).
- `link_text(cid, name, repo)` is the project's own canonical serializer: `json.dumps(...,
  indent=2, sort_keys=False)` plus a trailing newline, in the fixed key order `project, name,
  repo`. `sapience-project-bind.sh` should reproduce this exact byte-for-byte shape (2-space
  indent, trailing newline, that key order) so a server-side consumer and this script's own writer
  never disagree about the file's bytes once `REPO_LINK_FOR` is eventually enabled.
- `find_link` walks **up** from a start directory (bounded 40 levels) and returns the first valid
  link file — i.e. a nested directory inside a repo with `.sapience/project.json` at its root
  would still resolve correctly server-side, which is relevant context for why the dispatch
  requires resolving to the git toplevel via the shared worktree-resolution block rather than
  using the invocation `cwd` directly.

**`_people_project_share` and `project_split_confirmed` — confirmed the ownership mechanics.**
Read in full at `brain_server.py:57940` onward and `brain_server.py:28620-28652`. The route
accepts `{to, project:{kind,key}, follow, ...}` exactly as the dispatch describes; for
`kind:"project"` it resolves/sets the display name and requires the project to be non-empty
*unless* `PROJECT_CHAT_ON` and the project is a named, still-empty "Start a project" channel —
confirming the dispatch's framing that creating a fresh, deliberately-named, initially-empty
project is a supported path, not a workaround. `project_split_confirmed`'s `cross = doors &
(sent | added | first_doors-if-owner-and-not-sent)` confirms exactly the ownership asymmetry the
dispatch cites: a **non-owner** member's tagged notes can only cross once they land in `sent` or
an explicitly-confirmed `added` book (i.e. they start as suggestions only the author sees); the
**owner**, on the first pass (`not sent`), additionally gets `first_doors` without that per-note
confirmation. Creating the project (becoming `created_by`) is therefore not a stylistic
preference but the mechanical precondition for `follow:true` notes to flow unconfirmed, exactly
as the dispatch states.

**Dead-path confirmation (REPO_LINK_FOR).** `repo_link.py`'s module docstring and `enabled()`
function confirm `REPO_LINK_FOR` is an env-var-gated allowlist (comma/space-separated token
prefixes, or `'*'`), off by default (`''`), with an unlisted token's new routes answering 404 "as
if they did not exist." This corroborates the dispatch's two independent live-probe
confirmations that the flag is currently off for this token, and confirms the module is designed
so that `.sapience/project.json` in exactly the `{project, name, repo}` shape this task writes
becomes natively consumed server-side the moment the flag is enabled for this token — no format
migration would be needed later, only a flag flip upstream.

### External Resources

No external web research was needed: every mechanism this task depends on is implemented in
source files already readable on this machine (`brain_server.py`, `repo_link.py`,
`~/.sapience/mcp.py`, `~/.sapience/config.json`), and the dispatch states all vault-side
behaviors were already verified live against `app.spnc.ai` during the investigation that produced
this task breakdown. Re-running live HTTP probes against the vault was out of scope for this
research pass (no vault-mutating or vault-querying call was made; this pass only read local
files), consistent with the dispatch's instruction to avoid rediscovering what was already
verified.

## Recommendations

1. **Build the lib first.** `scripts/lib/sapience-api-lib.sh` should expose at minimum:
   `sapience_resolve_host`, `sapience_resolve_token` (or a single init function setting both),
   `sapience_post <path> <json-body>` and `sapience_get <path> [query-string]`, each applying the
   exact precedence confirmed above and never echoing the token (not even under `--dry-run`,
   where only the *body* is printed with the token redacted — mirroring `sapience-remember.sh`'s
   `jq '.token = "***REDACTED***"'` pattern for POST bodies that carry the token in the body, and
   mirroring its URL-embedding `--arg v "$sapience_token" '$v|@uri'` pattern for GET calls that
   carry the token as a query parameter, so a GET helper's `--dry-run` must redact the token out
   of the printed URL, not just out of a JSON body).
2. **Have both new scripts source the lib, not re-derive the precedence.** This is the one
   behavior change the dispatch asks for relative to the extension's current duplication norm;
   anything a future `sapience-publish.sh` (task 648) needs should also source this same lib
   rather than adding a fourth copy.
3. **Carry the worktree-resolution block by copy, not by sourcing the lib.** Keep the existing
   convention (each consumer carries its own byte-identical copy of the marker-delimited block)
   rather than moving `resolve_checkout_toplevel` into the lib and having the two new scripts call
   it from there — the lockstep test's whole design assumes N independent copies that must agree,
   and folding it into the lib would turn that into a single copy no comparison can catch drifting
   from a hypothetical future duplicate. If, during planning, a reviewer prefers consolidating the
   function into the lib instead, that is a legitimate alternative, but it requires rewriting Case
   30's guarantee (comparing the lib's one copy against the remaining five duplicates, or
   retiring the duplicates entirely) rather than leaving it as-is.
4. **Extend `LOCKSTEP_FILES` in `test-sapience-mcp-registration.sh`.** Whichever of the two new
   scripts end up carrying the marker block (per Hard Constraint 3, likely both, since both need
   repo-root resolution — `sapience-project-bind.sh` to locate `.sapience/project.json`'s write
   target, `sapience-vault-read.sh` to locate `specs/state.json`/`specs/events.jsonl`/etc.) must
   be appended to the `LOCKSTEP_FILES` array (currently five hardcoded paths at lines 1218-1224)
   so Case 30's byte-identical guarantee actually covers the new copies. This is new test
   maintenance in an *existing* test file outside this task's own new-file list, but the dispatch
   file_scope lists `scripts/tests/test-sapience-project-bind.sh` and
   `scripts/tests/test-sapience-vault-read.sh` as the only new test files — extending
   `test-sapience-mcp-registration.sh` is a small, necessary edit to an existing file in the same
   directory and should be called out explicitly in the plan rather than left implicit.
5. **`sapience-project-bind.sh`'s confirm-or-refuse posture.** Require both an explicit
   `--name "<display name>"` (or positional) argument and an explicit `--confirm` (or similarly
   named, non-default) flag; refuse with a clear message and exit nonzero if either is missing,
   so no autonomous/unattended invocation can accidentally fire the outward-facing
   `/v1/people/projects/share` mutation. Print the exact payload (`to`, `project.key`, `follow`)
   before sending it, consistent with task 648's `--dry-run` literal-payload convention, so a
   human confirms what will actually be sent even in the confirmed path.
6. **Support multiple repos' bindings cleanly.** Since `.sapience/project.json` lives at a given
   repo's root and `find_link`/the worktree-resolution block both resolve per-repo, no special
   multi-repo logic is needed inside either script beyond always resolving the *current* repo's
   toplevel before reading or writing — "supporting multiple repos" is satisfied by each repo
   having its own independently-resolved file, not by any single script needing to enumerate
   repos.
7. **`sapience-vault-read.sh`'s output contract.** Since task 649's draft-assembly command is the
   stated consumer and does not yet exist, define this script's output as a single JSON (or
   clearly-delimited text) envelope on stdout bundling the local-side and vault-side read results,
   analogous to `sapience-retrieve.sh`'s `<memory-context>` envelope convention, so task 649 has a
   single, stable interface to consume rather than needing to know which of the ~9 separate
   local/vault sources produced which field. The plan phase should pin this envelope's exact shape
   since it is the hand-off contract to an as-yet-unwritten consumer.
8. **Reuse, don't duplicate, the GET-retry/cold-start handling.** `sapience-vault-read.sh`'s vault
   reads should route through the lib's `sapience_get` helper, which in turn should fold in
   `sapience-retrieve.sh`'s bounded-one-retry-on-503-with-`starting:true` behavior (confirmed
   present at that script's header and body) rather than re-adding it ad hoc per call site, since
   seven-plus GET calls in one script multiply the cost of inconsistent retry handling.

## Decisions

- Confirmed (no change needed): all vault-side mechanism claims in the dispatch (the
  `/v1/people/projects/share` request/response shape, `project_split_confirmed`'s ownership
  asymmetry, `repo_link.py`'s exact validation rules, the `REPO_LINK_FOR` dark-path status, and
  the credential precedence) match the live source files read during this research pass.
- Decision: the new `scripts/lib/sapience-api-lib.sh` is the first `scripts/lib/` directory in
  this extension and intentionally supersedes, for this task's three new scripts only, the prior
  per-script-duplication norm documented in `sapience-remember.sh`'s header — that norm's own
  stated rationale (duplication avoids expanding `file_scope`) does not bind a task whose
  `file_scope` already names the lib.
- Decision: the marker-delimited worktree-resolution block stays a **duplicated-and-compared**
  pattern (copied into each new script that needs it), not refactored into the new shared lib,
  to avoid breaking the lockstep test's comparison semantics; `test-sapience-mcp-registration.sh`
  Case 30's `LOCKSTEP_FILES` array needs a corresponding edit, planned explicitly rather than
  discovered during implementation.

## Risks & Mitigations

- **Risk**: `sapience-project-bind.sh`'s interactive confirm step is accidentally invokable from
  an unattended `/orchestrate` dispatch, firing an outward-facing notification to the collaborator
  without a human present. **Mitigation**: require the explicit name argument AND a separately
  non-default confirm flag (recommendation 5); neither should have a default value that could be
  satisfied by an empty or placeholder invocation.
- **Risk**: a future edit to either new script's worktree-resolution copy silently drifts from the
  other five (now seven) copies, and nothing catches it because `LOCKSTEP_FILES` was never
  extended. **Mitigation**: recommendation 4, planned as an explicit implementation step, not left
  to incidental discovery.
- **Risk**: `sapience-vault-read.sh` accumulates seven-plus independent GET call sites, each
  re-deriving retry/error-handling logic ad hoc, producing inconsistent behavior across the
  sources it aggregates. **Mitigation**: route every vault GET through the shared lib's one GET
  helper (recommendation 8), so retry/error semantics are defined once.
- **Risk**: `.sapience/project.json`'s writer diverges byte-for-byte from `repo_link.py`'s
  `link_text` serializer (key order, indentation, trailing newline), which would not break
  `parse_link` (object-shape tolerant) but would make the file's bytes inconsistent with what the
  server itself would produce once `REPO_LINK_FOR` is enabled, complicating any future diff-based
  verification. **Mitigation**: reproduce `link_text`'s exact serialization in
  `sapience-project-bind.sh` (recommendation/finding above), not just its accepted *shape*.
- **Risk**: the project-creation POST's own failure/success response shape (`{ok, project, to}`)
  is different from `/ingest-kos`'s (`{written, gated, set_aside, ok}`), and a careless port of
  `sapience-remember.sh`'s exact field checks would check fields that do not exist on this
  response. **Mitigation**: the loud-failure *discipline* (treat anything short of an unambiguous
  success as a loud, non-zero-exit failure, never a success-shaped guess) transfers; the specific
  field names do not, and the plan/implementation should write field checks against the
  `_people_project_share` response shape confirmed in this report, not copy
  `sapience-remember.sh`'s field names verbatim.

## Context Extension Recommendations

- **Topic**: shared-lib precedent inside the sapience extension.
- **Gap**: `context/project/sapience/domain/per-repo-scoping.md` and the other existing domain
  docs explain *why* `sapience-remember.sh`/`sapience-retrieve.sh` duplicate their resolution
  logic, but there is no context file documenting the newer convention (one extension, multiple
  `scripts/lib/` consumers) this task introduces.
- **Recommendation**: once this task and task 648 land, consider a short addition to
  `context/project/sapience/README.md` (or a new domain file) naming
  `scripts/lib/sapience-api-lib.sh` as the canonical host/token/API-resolution helper for any
  future sapience script, so a later task does not re-derive the precedence a fifth time the way
  `sapience-remember.sh`'s header shows happened a second time already.

## Appendix

- Search queries used: none (web search was not needed for this research pass; see "External
  Resources" above).
- Files read in full or in relevant part: `agent-system/extensions/sapience/manifest.json`,
  `agent-system/extensions/sapience/rules/sapience-write-path.md`,
  `agent-system/extensions/sapience/scripts/sapience-remember.sh`,
  `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` (header/resolution portion),
  `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` (Case 30 and
  surrounding lockstep-guard context), `.claude-extensions.json` (sapience entry),
  `/home/benjamin/Projects/Sapience/sapience-app/repo_link.py` (in full),
  `/home/benjamin/Projects/Sapience/sapience-app/brain_server.py` (`_people_project_share`,
  `project_split_confirmed`, `project_seat_doors`), `~/.sapience/mcp.py` (credential-resolution
  lines only), `~/.sapience/config.json` (key names and non-sensitive `capture.projects` entries
  only — no secret values read or reproduced), `specs/TODO.md` (tasks 647/648/649 full
  descriptions).
- References: `.claude/rules/source-store-deploy-boundary.md`,
  `context/project/sapience/domain/per-repo-scoping.md` (referenced, not re-read in full this
  pass — already summarized correctly by the dispatch and by `sapience-write-path.md`).
