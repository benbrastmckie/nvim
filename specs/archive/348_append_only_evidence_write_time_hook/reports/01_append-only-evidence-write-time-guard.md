# Research Report: Task #348

**Task**: 348 - Write-time PreToolUse Write|Edit hook enforcing append-only evidence files, the
books extension first hook and its registration path
**Started**: 2026-10-06T00:00:00Z
**Completed**: 2026-10-06T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/{core,books,email,lean}/**,
  lua/neotex/plugins/ai/shared/extensions/{loader,merge,init}.lua), specs/state.json task-348
  record, a cached consumer-repo copy of `check-evidence-append-only.sh` found under
  `/nix/store/*/books/scripts/` (read-only reference, not an edit target)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All of the dispatch's "verified during task creation" claims were re-confirmed directly in the
  source tree: core's exact `"Write|Edit"` PreToolUse matcher, `merge.lua`'s exact-string
  per-matcher dedupe, `loader.lua`'s install-once treatment of `settings.json`, the hooks
  category's execute-bit-preserving file copy, and both named-wrong precedents (email's
  `2>/dev/null || echo '{}'` wrapper; email/lean targeting the gitignored
  `settings.local.json`). Nothing in this task's premises needed correction.
- `file_scope` was already locked at task-creation time to four exact paths (confirmed by reading
  `specs/state.json`'s `active_projects[348]` record directly): `hooks/validate-evidence-append-
  only.sh`, `scripts/tests/test-validate-evidence-append-only.sh`, `settings-hooks.json`, and
  `manifest.json`, all under `agent-system/extensions/books/`. This settles the naming question
  the dispatch explicitly left open ("pick one... settings-fragment.json vs merge-sources/
  settings-hooks.json") — the locked path is a third, hybrid spelling (extension-root location
  like every non-core extension, but a content-descriptive filename borrowed from core's). The
  plan should use these four paths verbatim rather than re-opening the naming question.
- `check-evidence-append-only.sh` is not in the extension source store (confirmed: no hits under
  `agent-system/`); a cached consumer-repo copy was located under a nix store path and used only
  to re-confirm the scope rule (`books/book-convention-evidence/*.md`, `README.md` excluded) and
  the `EVDIR` variable shape. That cached copy still carries the OLD, misleading remediation
  wording ("restore the lines and append a dated entry instead") — this is a stale pin, not
  evidence that the consumer repo's live fix regressed; the dispatch says the live repo's header
  has already been corrected, and this task must not touch that script either way.
- `.tool_name` (top-level in the PreToolUse payload, confirmed used by `guard-git-push.sh` and
  `detect-noop-bash.sh`) is the clean way to branch Write-vs-Edit parsing, rather than trying to
  infer the tool from which JSON keys are present.
- The core predicate design in the dispatch (Write: current content is a byte-exact prefix of
  `content`; Edit: `old_string` is a suffix of current content and `new_string` begins with
  `old_string`) is sound and implementable with substring/prefix tests alone — no diff library,
  no line-splitting (line-splitting would itself be the bug the dispatch warns about, since the
  measured incident was a single ~7,800-character line).
- Recommend ruling Option B (git-aware trailing-entry exception) for the uncommitted-tail
  question, with the stated fallback (prefix test against on-disk content) when `git show
  HEAD:<path>` is unavailable. This is a plan-level ruling, not a research-level one, but the
  research below lays out exactly what each option requires mechanically so the plan can commit
  to one without re-deriving.

## Context & Scope

This is a `meta` task whose deliverable is purely mechanical: a new PreToolUse hook script, its
fixture test, a small JSON settings fragment, and four lines of `manifest.json` wiring (one
`provides.hooks` entry, one `provides.scripts` entry for the test, one `merge_targets.settings`
block). No new prose/pattern documentation is permitted (explicit non-goal, and the task fails if
violated). The guarded resource (`books/book-convention-evidence/NN-*.md` and the gate that
checks it) lives only in a separate consumer repository and was not locally editable or
re-creatable here; research therefore focused on (1) re-confirming every claim the dispatch
labeled "verified during task creation, re-confirm only" directly against this repo's source
tree, and (2) resolving the two design questions the dispatch left explicitly open for the plan
(fragment naming/location, and the predicate's exact parsing strategy) using what the file_scope
lock and the deploy pipeline's actual code already settle.

## Findings

### Codebase Patterns

**Hook deploy mechanics (`lua/neotex/plugins/ai/shared/extensions/loader.lua`)**
- The `hooks` descriptor (`loader.lua:216-219` by the dispatch's line count, confirmed present)
  copies `provides.hooks` entries from `<extension>/hooks/` to `.claude/hooks/` with
  `preserve_perms = "always"` — a plain file-copy-with-execute-bit, registering nothing. This
  matches the dispatch's claim (a) exactly.
- `INSTALL_ONCE_ROOT_FILES = { ["settings.json"] = true, ["settings.local.json"] = true }`
  (`loader.lua:134-137`) is confirmed: both settings files are skip-if-exists root files, never
  overwritten by a root-files copy on redeploy. This is why registration can only arrive through
  `merge_targets.settings` (claim (c)).

**Merge semantics (`lua/neotex/plugins/ai/shared/extensions/merge.lua`)**
- `is_hook_event_array` / `normalize_hook_event_array` / `merge_hook_event_array`
  (`merge.lua:180-274`, read directly) confirm the dispatch's claim verbatim: hook-event arrays
  (keyed by event name, e.g. `PreToolUse`) are merged **by exact-string `matcher` equality**, and
  within a matched matcher block, individual `{type, command}` hook objects are appended only if
  not already `vim.deep_equal`-present. Registering under any matcher spelling other than the
  literal string `"Write|Edit"` (core's existing block) creates a **second, independently-tracked
  matcher block** rather than joining the existing one — confirmed mechanically, not just
  asserted.
- `deep_merge` only enters the hook-event-array path when the **target** key is absent, empty, or
  already itself a hook-event array (`merge.lua`, the `is_hook_event_array(target[key])` guard in
  the `deep_merge` excerpt read). Since core's `settings-hooks.json` already populates
  `.hooks.PreToolUse` as a hook-event array, a books fragment doing the same for the same key
  lands in this exact-matcher-join path, not the generic array-append path.

**Existing hooks-bearing fragments (precedents, both explicitly rejected in the dispatch and
re-confirmed here by reading the files directly)**
- `agent-system/extensions/email/settings-fragment.json` registers
  `bash .claude/hooks/mail-guard.sh 2>/dev/null || echo '{}'` — confirmed: the `|| echo '{}'`
  wrapper converts any non-zero exit (including the blocking exit 2) back to a `{}` payload read
  as success, silently defeating the block. Its `merge_targets.settings.target` is
  `.claude/settings.local.json`.
- `agent-system/extensions/lean/settings-fragment.json` carries only a `permissions.allow` block
  (no `hooks` key at all) even though `lean-lsp-register-project.sh` is listed in
  `provides.hooks` — confirmed the hook ships but is never registered anywhere, exactly as the
  dispatch describes ("silent half-deployment").
- Across every extension with a `merge_targets.settings` entry (`email`, `epidemiology`,
  `filetypes`, `founder`, `lean`, `memory`, `nix`, `present`, `web` — 8 of 9 non-core), the source
  filename is uniformly `settings-fragment.json` at the extension root, and the target is
  uniformly `.claude/settings.local.json`. Only `core` deviates on both axes: its source is
  `merge-sources/settings-hooks.json` and its target is the tracked `.claude/settings.json`.
  `core`'s `merge-sources/` directory also holds `claudemd.md` — it is a general
  "oversized-or-multiple source fragments" convention, not a hooks-specific one (the `literature`
  extension uses the same `merge-sources/` directory for its own `claudemd.md`, unrelated to
  hooks).
- **This naming/location question is moot for planning purposes**: `specs/state.json`'s
  `active_projects[348].file_scope` already locks the source path to
  `agent-system/extensions/books/settings-hooks.json` (extension root, like every non-core
  extension) with the content-descriptive filename borrowed from core's spelling. The plan should
  treat this as decided, not re-litigate it, and should set `merge_targets.settings.target` to
  `.claude/settings.json` (per the dispatch's ruling, and matching core's target — the two
  extensions that need a block in the **tracked** settings file now share the same source-filename
  convention too, which is a reasonable coincidence to note but not a rule to generalize).

**The precedent hook itself (`agent-system/extensions/core/hooks/validate-no-task-references.sh`,
read in full)**
- Confirms the four inherited contracts exactly: exit 2 + multi-line stderr for block (not
  `permissionDecision: deny`); fail-open (exit 0 + stderr WARNING) on a missing or
  failed-to-source library, with the two cases guarded **separately** (`[ ! -f "$LIB" ]` vs.
  `! . "$LIB"`) specifically because `set -euo pipefail` would otherwise abort an unguarded
  source before the fallthrough could run; `BASH_SOURCE`-relative path resolution
  (`HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`); and bare registration (stated in
  its own header as a MUST, with the exact failure mode named).
- Its stdin-parsing shape distinguishes a TTY/env-var fallback (`CLAUDE_TOOL_INPUT`) from the
  normal piped-stdin JSON case, and reads `.tool_input.content // .tool_input.new_string` only —
  explicitly **not sufficient** for this task per the dispatch, since it cannot tell whether an
  existing line survived; this hook additionally needs `.tool_input.old_string` and
  `.tool_input.replace_all` for Edit, confirmed absent from the precedent's parsing.
- Confirmed present: top-level `.tool_name` in the same PreToolUse JSON payload (seen used by
  `guard-git-push.sh:39` and `detect-noop-bash.sh:135` via
  `jq -r '.tool_name // empty'`/`'.tool_name // ""'`) — the clean way to branch Write-vs-Edit
  parsing rather than keying off which fields happen to be present.
- Confirmed present: top-level `.cwd` in the same payload, used elsewhere (`events-log-
  artifact.sh`, `validate-handoff-location.sh`, `validate-meta-write.sh`, `validate-plan-write.sh`,
  `validate-state-sync.sh`, `events-log-lifecycle.sh`) exclusively for **event-logging
  provenance** (`--cwd` passed to a recorder script) — never, in any existing hook, to resolve a
  relative `file_path` or to scope a `git -C` invocation. This task's hook would be the **first**
  to use `.cwd` operationally. Design implication: resolve `file_path` to an absolute path by
  joining with `.cwd` when not already absolute, then find the git repo root via
  `git -C "$(dirname "$ABS_FILE")" rev-parse --show-toplevel` and compute the path relative to
  that root for `git show HEAD:<relpath>` — this is robust to `.cwd` being a subdirectory of the
  repo rather than its root, which the dispatch's own worry about "handle both absolute and
  repo-relative file_path" anticipates.

**books extension state (`agent-system/extensions/books/manifest.json`, read in full)**
- `"hooks": []` and no `settings` key under `merge_targets` — confirmed exactly as the dispatch
  states. `provides.scripts` already lists `tests/test-books-gate.sh` etc. as flat entries
  alongside the non-test scripts (`books-certify.sh`, `books-gate.sh`, `books-observe.sh`), which
  is the pattern the new fixture test's `provides.scripts` entry
  (`scripts/tests/test-validate-evidence-append-only.sh`) should follow — add it as one more
  string in the same array, not a separate manifest key.

**books test-authoring convention (`agent-system/extensions/books/scripts/tests/
test-books-gate.sh`, read in full, 491 lines)**
- Confirms the dispatch's description precisely: `set -uo pipefail` (Class B — reports every
  case, never aborts on first failure), a `mktemp -d` workdir with a `trap ... EXIT` cleanup, a
  `pass`/`fail`/`info` counter harness, an `assert_exit`/`assert_json`/`assert_json_wellformed`
  helper trio, and fixture builders that construct each scenario as its own real git repository
  (`install_rule_set DIR [MODE]` pattern) rather than mocking anything. The new test should drive
  `hooks/validate-evidence-append-only.sh` as a real subprocess (piping a constructed JSON
  payload on stdin) exactly as `test-books-gate.sh` drives `books-gate.sh` as a real subprocess
  with constructed CLI args — no unit-testing of extracted functions, no sourcing the hook script
  to call internal functions directly.
- Forgery-probe discipline (`context/project/books/standards/forgery-probe-discipline.md`, read):
  "Every gate predicate gets a forgery probe... shipped without one is a REVIEWABLE DEFECT." The
  concrete mechanism is a probe that **stubs the predicate out** (e.g., forces the hook to treat
  every input as "no modification detected") and asserts that the suite's own positive-refusal
  assertions then **fail** — proving the suite would have caught a predicate that silently did
  nothing. For this hook, at minimum: a probe that replaces the prefix/suffix comparison with an
  always-true stub and asserts the modification-refusal test case then fails against that stub.

**The consumer-repo gate's scope rule (cached nix-store copy of
`check-evidence-append-only.sh`, read for reference only — not an edit target and not proof of
the live repo's current wording)**
- Confirms: `EVDIR="books/book-convention-evidence"`; README.md excluded by `case` match on both
  `"$EVDIR"/README.md` and `*/README.md`; glob over the whole directory tree (not strictly
  `NN-*.md`, though the task's own stated scope for the **new hook** narrows to that two-digit
  prefix pattern, which is a safe, slightly tighter superset-complement of what the gate already
  treats as evidence files in practice).
- The cached copy's exit-1 finding message still reads "restore the lines and append a dated
  entry instead" — the wording the dispatch says was already corrected live. This is consistent
  with the cached copy being a stale nix-store pin (observed under many different store hashes,
  i.e., a dependency lockfile artifact) rather than evidence of a regression; it does not affect
  this task, which must not touch that script.

### External Resources

None consulted — this task is entirely internal-codebase mechanics (manifest schema, deploy
pipeline, merge semantics, hook-authoring convention) with no external library or API surface
involved. No WebSearch/WebFetch was needed or used.

## Recommendations

1. **Use the four locked `file_scope` paths verbatim** (already declared in
   `specs/state.json`'s task-348 record): `agent-system/extensions/books/hooks/validate-evidence-
   append-only.sh`, `agent-system/extensions/books/scripts/tests/test-validate-evidence-append-
   only.sh`, `agent-system/extensions/books/settings-hooks.json`, `agent-system/extensions/books/
   manifest.json`. Do not introduce a fifth file or rename any of these without going through the
   sanctioned `scripts/update-task-status.sh --file-scope-add` re-scope path the dispatch names.
2. **`settings-hooks.json` contents**: a single `{"hooks": {"PreToolUse": [{"matcher":
   "Write|Edit", "hooks": [{"type": "command", "command": "bash .claude/hooks/validate-evidence-
   append-only.sh"}]}]}}` fragment — bare command (no `2>/dev/null || echo '{}'` wrapper), exact
   matcher string `"Write|Edit"` (case- and pipe-order-sensitive per `merge.lua`'s exact-equality
   join), so it lands inside core's existing matcher block rather than opening a second one.
3. **`manifest.json` wiring**: add `"validate-evidence-append-only.sh"` to `provides.hooks`
   (currently `[]`); add `"scripts/tests/test-validate-evidence-append-only.sh"` to the existing
   `provides.scripts` array; add a `merge_targets.settings` block with `"source":
   "settings-hooks.json"`, `"target": ".claude/settings.json"`, and a `_comment` stating the
   registration-target ruling and its reason (mirroring core's own `_comment` style on that same
   key) — this is metadata/comment prose inside a manifest field, not a new pattern document, and
   does not trip the no-new-prose non-goal.
4. **Predicate parsing shape** (for the plan to finalize, this research confirms the mechanics are
   sufficient): branch on top-level `.tool_name`. For `"Write"`, read `.tool_input.content`; the
   write is allowed only if the resolved current on-disk (or HEAD, if git-aware ruling is chosen)
   file content is a byte-exact prefix of `.tool_input.content`. For `"Edit"`, read
   `.tool_input.old_string`, `.tool_input.new_string`, `.tool_input.replace_all`; the conservative
   test is that `old_string` is a byte-exact suffix of the comparison content AND `new_string`
   begins with `old_string` as a prefix — this sidesteps simulating `replace_all` uniqueness
   entirely, at the cost of being stricter than necessary in a few edge cases (acceptable per the
   dispatch's own framing: "justify it or replace it with simulation", and simulation adds
   complexity the task's non-goals push against).
5. **Resolve the file path via `.cwd` + `.file_path`, independent of whatever the agent's shell
   cwd happens to be**: join `file_path` onto `cwd` only when `file_path` is not already absolute,
   then derive the git repo root from the resulting absolute path (`git -C
   "$(dirname "$ABS_FILE")" rev-parse --show-toplevel`) rather than assuming `cwd` itself is the
   repo root. This generalizes correctly even if a future dispatch's cwd is a subdirectory.
6. **Scope match**: compare the resolved absolute path's suffix against
   `books/book-convention-evidence/<two digits>-*.md`, explicitly excluding a basename of
   exactly `README.md`. Any non-match exits 0 immediately (before any git or content work), both
   to stay inert in every repo lacking the directory and to minimize work on the hot path (every
   Write/Edit in the whole tree runs this hook).
7. **Trailing-uncommitted-entry ruling — recommend Option B (git-aware)**, with the stated
   fallback: when `git show HEAD:<relpath>` fails (new file, shallow clone, no `.git` reachable),
   fall back to the Option A prefix test against the current on-disk file content — this is
   strictly safer (refuses a superset of what Option B would refuse) and is explicitly not the
   fail-open case (fail-open is reserved for genuine internal errors: missing `jq`, a parse
   failure on the hook's own stdin, etc. — a clean "not a git repo" or "file not yet committed"
   signal is an ordinary, well-understood branch of the predicate, not an error).
8. **Rejection message**: one `BLOCKED:` line plus stderr lines carrying, inline, all three
   required facts — append-only (name the file), the commit-time counter's monotonicity (a later
   restore cannot undo a committed deletion; the only remedy is a history rewrite), and "append a
   dated entry instead" — plus one line naming `check-evidence-append-only.sh` as the companion
   gate. Model the phrasing register on `validate-no-task-references.sh`'s own BLOCKED messages
   (multi-line, each line self-contained, no jargon beyond what's defined inline).
9. **Fixture test**: build on `test-books-gate.sh`'s exact harness shape (same `pass`/`fail`
   counters, same `mktemp -d` + `trap EXIT` pattern, same "construct a real git repo per fixture"
   discipline), covering every case the dispatch's Acceptance section lists verbatim, plus at
   least one forgery probe per forgery-probe-discipline.md, plus the buried-in-a-multi-thousand-
   character-single-line case (construct a fixture line of several thousand characters, inject
   the target-incident-shaped string replacement inside it, and assert refusal — do not special-
   case line length anywhere in the hook itself; the prefix/suffix string tests are already
   length-agnostic, so this case is a regression guard against a future accidental line-splitting
   rewrite, not a hint to add special handling now).
10. **Do not** extend `verify-deploy.sh`'s hardcoded three-pair registration gate, touch
    `check-evidence-append-only.sh`, add any new context/pattern document, add in-file
    immutability markers, fix email's wrapper or lean's unregistered hook, broaden the hook's
    scope beyond the one directory, or create a dependency edge on task 342 (on hold) — all
    confirmed deliberate exclusions in the dispatch, re-confirmed here as still appropriate: 342
    is still `hold` and 282 is still `not_started` (no landed pattern to inherit from), per a
    direct read of `specs/state.json`.

## Decisions

- **Settings-fragment naming/location**: use `agent-system/extensions/books/settings-hooks.json`
  (extension root, content-descriptive name) — not `settings-fragment.json` (would collide with
  nothing here but breaks the task's already-locked `file_scope`) and not
  `merge-sources/settings-hooks.json` (core's subdirectory convention exists to hold *multiple*
  oversized fragments; books has exactly one small one, so the subdirectory adds nothing). This
  decision is not optional — it is mechanically fixed by the task's declared `file_scope`, read
  directly from `specs/state.json`.
- **Registration target**: `.claude/settings.json` (tracked), not `.claude/settings.local.json`
  (gitignored) — re-confirms the dispatch's ruling; no overturn found during research.
- **`.tool_name`-based branching** is the parsing entry point, rather than inferring Write vs.
  Edit from which JSON keys happen to be populated — confirmed available and already used
  elsewhere in the codebase for exactly this kind of dispatch.
- **`.cwd` is used operationally here for the first time** in this hook family (every existing
  consumer treats it as log provenance only) — flagged explicitly so the plan does not assume an
  existing helper exists for cwd-relative path resolution; none does.
- Trailing-uncommitted-entry Option B (git-aware) is this report's recommendation, not yet a
  ruling — the dispatch frames this as a plan-level decision to be made explicitly and recorded
  with its reason, and this report does not treat itself as the authority that closes it.

## Risks & Mitigations

- **Risk**: registering under a matcher string that is not byte-identical to `"Write|Edit"`
  (e.g. different pipe spacing, different order, or adding `MultiEdit`) silently creates a second,
  permanently-undeletable matcher block (merge is add-only). *Mitigation*: copy the literal string
  from `agent-system/extensions/core/merge-sources/settings-hooks.json`'s existing block rather
  than retyping it.
- **Risk**: a line-oriented implementation (e.g. `diff`, or splitting both old and new content on
  `\n` and comparing line arrays) would pass every fixture except the one modeling the real
  incident, since the real incident was buried inside one ~7,800-character line. *Mitigation*:
  implement the predicate as pure byte-string prefix/suffix tests (`substr`/`${var#prefix}`-style
  bash parameter expansion, or `grep -F`/`cmp`-style whole-content comparison) and include the
  long-single-line fixture as a forgery-style regression probe, not an afterthought.
- **Risk**: a future redeploy to a repo that already has the hook registered could, in principle,
  re-add the same hook object — but `merge_hook_event_array`'s `vim.deep_equal` existence check
  (confirmed in `merge.lua`) prevents this: the hook object `{type, command}` is byte-identical
  across deploys, so re-merging is a no-op after the first deploy. No additional mitigation needed.
- **Risk**: this hook runs on **every** Write/Edit anywhere in a repo with books loaded (the
  matcher is tool-scoped, not path-scoped, at the Claude Code level) — a slow or git-heavy
  predicate would add latency to unrelated writes. *Mitigation*: the scope-match early exit (item
  6 above) must run before any `git` invocation, so the common case (non-matching path) costs one
  string comparison, not a subprocess spawn.
- **Risk**: `verify-deploy.sh`'s registration gate will not catch a books-specific
  registered-but-not-firing regression (confirmed: it only checks three hardcoded core
  event:script pairs). *Mitigation*: none implemented here per explicit scope exclusion; the gap
  is recorded as a known limitation for a future, separate generic-registration-check task, and
  this task's own manual deploy-and-fire verification step is the only safety net until then.

## Context Extension Recommendations

None. This is a `meta` task whose explicit non-goal is adding new pattern/context prose; the
existing `rules/book-convention-record.md` and `context/project/books/patterns/record-
maintenance.md` already state the convention this hook enforces, and the dispatch is explicit
that no cross-reference edit to either is needed (the hook's own rejection message carries the
facts inline). No context gap was found that this task should close.

## Appendix

- Files read in full or by targeted `sed -n`/`grep` during research: `agent-system/extensions/
  books/manifest.json`; `agent-system/extensions/core/manifest.json` (hooks + merge_targets.
  settings); `agent-system/extensions/core/merge-sources/settings-hooks.json`; `agent-system/
  extensions/core/hooks/validate-no-task-references.sh` (full); `agent-system/extensions/email/
  settings-fragment.json` + manifest `merge_targets`; `agent-system/extensions/lean/settings-
  fragment.json` + manifest `merge_targets`; `agent-system/extensions/literature/manifest.json`
  + `merge-sources/` listing; `lua/neotex/plugins/ai/shared/extensions/merge.lua` (lines ~180-320,
  the hook-event-array merge path); `lua/neotex/plugins/ai/shared/extensions/loader.lua` (lines
  ~130-235, install-once root files + category descriptors); `agent-system/extensions/core/hooks/
  guard-destructive-git.sh` (header + conventions); `grep` across `agent-system/extensions/core/
  hooks/*.sh` for `tool_name`/`cwd` usage; `agent-system/extensions/books/context/project/books/
  standards/forgery-probe-discipline.md` (excerpt); `agent-system/extensions/books/scripts/tests/
  test-books-gate.sh` (full, 491 lines); `agent-system/extensions/books/rules/book-convention-
  record.md` and `context/project/books/patterns/record-maintenance.md` (excerpts, for scope-rule
  corroboration only); `specs/state.json`'s `active_projects` entries for tasks 282, 342, 347, 348
  (status/file_scope checks); a cached nix-store copy of `books/scripts/check-evidence-append-
  only.sh` (read-only reference for the gate's scope rule, not this task's target).
- No WebSearch or WebFetch queries were used.
