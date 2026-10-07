# Research Report: Task #263

**Task**: 263 - Consent-gated git push: grant semantics and enforcement mechanism
**Started**: 2026-09-29T22:43:00Z
**Completed**: 2026-09-29T22:49:00Z
**Effort**: Large (3 absorbed former tasks: 224, 225, 264; three implementation phases A/B/C)
**Dependencies**: 139 (forbid_concurrent_writer_history_rewrites) — completed/archived; its
history-rewrite predicate in `hooks/guard-destructive-git.sh` must compose with this task's grant
check, per the dispatch's predicate-ordering note.
**Sources/Inputs**: Codebase read of the full source store (`agent-system/extensions/core/`) —
hooks, scripts, rules, context standards, manifest.json, settings templates, skill-orchestrate
SKILL.md, orchestrate-cycle-postflight.sh, orchestrate-build-dispatch.sh, handoff-schema.md,
existing test fixtures. No web research was needed — this is entirely a codebase-mechanism design
task.
**Artifacts**: This report — `specs/263_consent_gated_git_push/reports/01_consent-gated-push-design.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- **The prohibition today is rule text only — zero mechanical enforcement exists.** Confirmed via
  fresh grep: no hook, script, or lint blocks `git push`, `gh pr create`, or `glab mr create`
  anywhere in the source store. This task is net-new enforcement, not a modification of existing
  enforcement, and can legitimately leave the system *stricter* than it found it.
- **The integrity problem has exactly one sound answer: the mint path must be a UserPromptSubmit
  hook, never a model-writable file.** `UserPromptSubmit` receives `.prompt` as the *literal,
  unexpanded* text the human typed (confirmed via the existing `wezterm-task-number.sh` hook,
  which pattern-matches `/research`, `/plan`, etc. directly against `.prompt` — this only works
  if slash commands are NOT pre-expanded before the hook fires). A dispatched subagent has no
  interactive prompt-submission lifecycle at all (already empirically confirmed in this task's own
  dispatch history: `AskUserQuestion` was unavailable to a dispatched agent) — but this must still
  be verified empirically before implementation ships, not merely inferred; see Finding 1 below
  for the exact verification step to run.
- **A new, structural finding not named in the dispatch text**: `root-files/settings.json` and
  `merge-sources/settings-hooks.json` are NOT interchangeable registration targets — they reach
  different populations of consumer repos (install-once template vs. add-only merge fragment into
  an *already-initialized* repo). Cross-checking this reveals that `guard-destructive-git.sh`'s
  own Bash-matcher PreToolUse registration is present in `root-files/settings.json` but **absent**
  from `merge-sources/settings-hooks.json` — meaning any consumer repo whose `.claude/settings.json`
  was first created before that Bash-matcher entry existed will never receive it via a later
  merge/regeneration. This task's new hooks (push guard, `/please` grant hook) must be registered
  in **both** files to avoid repeating that latent gap. See Finding 2.
- **The `.decisions.json` replay hazard the dispatch flags is real and directly confirmed by code
  read**, not merely hypothesized: `orchestrate-build-dispatch.sh` (~line 388-392) renders *every*
  entry in `.decisions.json` unconditionally into the next dispatch's `## Prior Decisions` block
  with no filtering by question shape, and `skill-orchestrate/SKILL.md` Move 4 appends *every*
  answered `ask_user` verdict to that file unconditionally. The design settled in the dispatch's
  "PATH REVIEW RULING" (a YES never mints anything; the relay only tells the user the `/please`
  line to type) closes this hazard **by construction** — nothing replayable is ever written — and
  this report confirms that is the only clean way to close it given the current unconditional
  append/render code paths (patching either of those two call sites to special-case one question
  shape would be a second, parallel special-case and is not recommended).
- **Recommended grant-token shape**: extend the `.git-snapshot-marker` KEY=VALUE precedent with a
  full target binding (`ACTION_CLASS`, `REMOTE`, `BRANCH`, `HEAD_SHA`, `FORCE`), a short expiry
  (600s, matching the absorbed text's stated 10-minute window — deliberately wider than the
  120s destructive-marker window since this grant is minted by a slower, human-typed `/please`
  invocation rather than an immediately-preceding script), single-use consumption (delete-on-use,
  same as the existing marker), and an HMAC-SHA256 tag computed with a key stored outside any path
  the model's own tool-call surface (Bash/Write/Edit, and any other write-capable tool currently
  wired to a repo) can write to. See Finding 3 and Design Question 1/5.
- **PR/MR creation and `/merge` stay fully user-only** — recommend *for*, with reasoning in Design
  Question 2 below. **Force-push and pushes to the default branch (master) stay categorically
  excluded from any grant** — recommend *for*, in Design Question 3.

## Context & Scope

Task 263 absorbed three former tasks (224, 225, 264) and is now scoped across three phases:

- **Phase A**: grant token format + `/please` UserPromptSubmit mint hook + HMAC integrity +
  `hooks/guard-git-push.sh` (new) + a grant-check addition to `hooks/guard-destructive-git.sh` +
  tests.
- **Phase B**: `commands/please.md` (user-only) + its never-list + the `pr-prohibition.md`
  exception + the CLAUDE.md/docs consistency sweep.
- **Phase C**: the orchestrator dispatch-relay path (`user_decision` → batched `AskUserQuestion`
  → user tells the agent the `/please` line to type — never a minted grant) + the two-cycle
  no-replay test.

This report covers the research/design questions for all three phases, since the dispatch names
all of them as this task's scope. It does not implement anything; `agent-system/extensions/core/`
is the edit target for the eventual plan/implementation, never `.claude/`.

## Findings

### Finding 1 — UserPromptSubmit payload shape and subagent non-triggering (verify, don't assume)

`hooks/wezterm-task-number.sh` (an existing, working `UserPromptSubmit` hook) reads stdin JSON and
extracts `.prompt`:

```bash
HOOK_INPUT=$(cat)
PROMPT=$(echo "$HOOK_INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")
```

It then pattern-matches literal slash-command prefixes (`/research`, `/plan`, `/task --recover`,
etc.) directly against `$PROMPT`. This only works correctly if `.prompt` is the **exact,
unexpanded text the user typed** — if Claude Code expanded a custom slash command's markdown file
content into the prompt *before* firing `UserPromptSubmit`, this existing hook's own prefix-match
logic would already be broken today (it is not; it demonstrably works, per its own doc comments
and the 3-tier logic it implements). This is strong indirect evidence — not yet a direct
empirical test — that a `/please <text>` mint hook can rely on `.prompt` carrying the literal
`/please ...` string.

**What is not yet directly verified**: that a dispatched subagent (via the `Agent`/Task tool, as
`/orchestrate` uses) can never cause a `UserPromptSubmit` firing. Indirect evidence for this is
strong: this very dispatch's own delegation context notes `AskUserQuestion` was unavailable to a
prior dispatched agent working on this same task family — subagents dispatched via the Agent tool
run in-process within the same session rather than as an independent interactive CLI invocation
with its own prompt-submission lifecycle, and they have no exposed mechanism to submit a "user
prompt" distinct from their own tool-call turns. **Recommendation for the plan/implementation
phase**: before wiring the mint hook, add a temporary logging line to a throwaway copy of the hook,
dispatch a subagent whose instructions literally begin with the text `/please ...`, and confirm the
log shows zero invocations for that dispatch. This is a cheap, concrete verification step and
should be run once, recorded in the implementation summary, and then removed — do not ship the
final hook without having run it at least once.

### Finding 2 — `root-files/settings.json` vs. `merge-sources/settings-hooks.json` are NOT interchangeable, and `guard-destructive-git.sh` itself shows the gap

This is not named in the dispatch text and materially changes the hook-registration design.
`context/patterns/regeneration-is-manual-only.md` documents:

> **Install-once root files.** `settings.json` ... is listed in `INSTALL_ONCE_ROOT_FILES`; the
> `root_files` category's descriptor-driven copier ... skips them entirely once the target
> exists. Anything added only to `root-files/settings.json` can therefore never reach an
> already-initialized repo. Additions intended for existing repos belong in
> `merge-sources/settings-hooks.json`, which is what the merge step actually reads.

Cross-checking the two files confirms a real, live instance of this gap:

- `root-files/settings.json`'s `PreToolUse` array has a `"matcher": "Bash"` entry running
  `guard-destructive-git.sh`.
- `merge-sources/settings-hooks.json`'s `PreToolUse` array has **only** a `"Write|Edit"` matcher
  (for `validate-no-task-references.sh`) — **no `Bash` matcher entry at all**, so
  `guard-destructive-git.sh` is not among the hooks the merge step would add to an
  already-initialized consumer repo.

This repository's own `.claude/settings.json` (verified by direct read) *does* carry the
`guard-destructive-git.sh` Bash-matcher entry, alongside `merge-sources/settings-hooks.json`'s own
additions (`detect-noop-bash.sh` on `PostToolUse`/`Bash`, `validate-handoff-location.sh` and
`validate-meta-write.sh` on `PostToolUse`/`Write|Edit`) — i.e. this repo received both the
install-once template's content and later additive merges, most likely because its
`.claude/settings.json` was last generated fresh (via a wipe/regenerate) at a point after
`guard-destructive-git.sh`'s entry already existed in `root-files/settings.json`. A consumer repo
that instead initialized its `.claude/settings.json` *before* that point, and has only ever
received incremental `merge-sources/settings-hooks.json` merges since, would never pick up the
Bash-matcher entry for `guard-destructive-git.sh` at all. This is a real, pre-existing propagation
gap, independent of this task.

**Consequence for this task's design**: the new push guard's `PreToolUse`/`Bash` registration, and
the new `/please` hook's `UserPromptSubmit` registration, must be added to **both**
`root-files/settings.json` (for fresh deploys) **and** `merge-sources/settings-hooks.json` (for
already-initialized consumer repos) — do not repeat `guard-destructive-git.sh`'s apparent
omission. `merge-sources/settings-hooks.json` already has a `UserPromptSubmit` block (`*` matcher,
`wezterm-task-number.sh` + `wezterm-preflight-status.sh`) that a `/please`-detection hook command
can be appended to as its own array entry — per `regeneration-is-manual-only.md`'s own guidance,
register it as its **own dedicated single-command matcher object**, not appended into the existing
shared `*` matcher array's `hooks` list for that object, to stay idempotent across re-merges
(`vim.deep_equal` object-level dedup, not append-into-hooks-array dedup).

Recommend the plan phase also flag (not necessarily fix, unless trivially in-scope) the
pre-existing `guard-destructive-git.sh` registration gap in `merge-sources/settings-hooks.json` as
a follow-up, since this task's own research surfaced it as a live latent defect.

### Finding 3 — Grant/key storage location: use the existing `specs/` ephemeral-state convention, not `.claude/`

`agent-system/extensions/core/manifest.json`'s `provides.root_files` includes `.gitignore`, and
`/home/benjamin/.config/nvim/.gitignore` (the deployed copy) opens with an explicit, documented
rule: `/.claude/` is blanket-ignored because "the `.claude/` deploy tree is a disposable build
artifact ... Wipe and regenerate ... at any time." That same file already establishes a rich
precedent of single-purpose, repo-scoped, gitignored state directories under `specs/` for exactly
this kind of ephemeral orchestrator state: `**/.commit-lock/`, `**/.sessions/`, `**/.scope-lock/`,
`/.orchestrate-worktrees/` (root-anchored, single top-level dir) paired with
`**/.worktree-registry/` (its `specs/`-scoped registry counterpart), etc.

Storing the grant (and its HMAC key) under `.claude/` is actively the *wrong* choice: a routine
`.claude/` wipe/regenerate (the dispatch's own header line: "Wipe and regenerate ... at any time")
would silently delete a live key, and — worse — deploy regeneration does not "reset to a known
value," it simply removes files not re-supplied by the source store, so the key's persistence
across wipes would be accidental rather than designed. Recommend instead: a single, repo-scoped
(not per-task, since a push grant is not intrinsically tied to one task) state location under
`specs/`, e.g. `specs/.push-grant/grant.json` and `specs/.push-grant/key` (or `specs/.push-grant.key`
as a sibling file, whichever the implementation prefers), gitignored via a new pattern in
`root-files/.gitignore`'s deployed target — actually the blanket `**/.git-snapshot-marker`-style
patterns live in the **top-level repo `.gitignore`**, not `root-files/.gitignore` (which only
covers `hooks/*.log`, `logs/`, `output/`, `*.tmp` — paths *inside* `.claude/`). Since the top-level
`.gitignore` is itself deployed via `provides.root_files` from a location this task's dispatch did
not name, the plan phase must locate that source file (search the source store for the file whose
`provides.root_files` entry target is the top-level `.gitignore` — likely `root-files/../.gitignore`
or a dedicated top-level-gitignore source file distinct from `root-files/.gitignore`) and add a new
`**/.push-grant/` (or equivalent) pattern there, following the exact style of the neighboring
`**/.worktree-registry/`/`**/.contention-claims/` entries (each with a one-paragraph rationale
comment, per that file's established convention).

**Threat model, stated honestly** (per the absorbed text's own instruction): the model's *only*
file-mutation channels are Claude Code's own tool-call surface (`Bash`, `Write`, `Edit`, and any
other write-capable tool a given deploy has wired, e.g. an MCP filesystem-write server) — every one
of those is interceptable by a `PreToolUse` hook returning `exit 2`. So a `PreToolUse` guard that
blocks any `Write`/`Edit` targeting the grant/key paths, plus a `Bash`-matcher guard blocking any
command whose redirection/argument targets those paths (mirroring `guard-destructive-git.sh`'s own
`COMMAND_SCAN` quote-stripped pattern-matching technique), genuinely closes the model's *write*
channel completely, for as long as the guard's pattern coverage is complete and no other
write-capable tool is wired without a matching hook. This is a real, load-bearing scope
qualification, not a residual weakness to gloss over: **the guard must be re-registered against
every write-capable tool matcher a given deploy has active**, not just `Bash|Write|Edit` — a
generic MCP tool with file-write capability, if ever added to this deploy's active tool roster,
would bypass a guard scoped only to those three matcher names unless its own matcher name is added
too. Recommend the plan explicitly document this scope boundary (which matchers the guard covers,
and that adding a new write-capable MCP tool later requires revisiting this guard's matcher list)
rather than silently assuming `Bash|Write|Edit` is exhaustive forever.

Separately, and independently of the write-guard: the model **can still read** the key (nothing
here claims otherwise) — a same-user shell process can read anything the hook can read. The HMAC's
value is therefore specifically in **integrity of a grant's provenance** (a grant with a valid HMAC
was written by the mint hook, which only fires on a genuine literal `/please` UserPromptSubmit,
never by the model directly writing JSON) rather than in confidentiality of the key. State this
precisely in the plan and command docs: the guarantee is "this grant was minted by a real human
prompt submission," not "the model cannot learn the key's value."

### Finding 4 — `guard-destructive-git.sh` line 20's dangling reference is confirmed dead

`hooks/guard-destructive-git.sh` line 20 states it is "Modeled line-for-line on
`.claude/hooks/block-pr-submission.sh`." A repo-wide search (source store and deployed tree alike)
confirms no file named `block-pr-submission.sh` exists anywhere, and `manifest.json` has no
`provides.hooks` entry naming it. This is stale documentation, not a live orphan artifact
(nothing on disk currently named that; it is a comment describing a file that either never shipped
under that name or was renamed/removed before this comment was corrected). **Fix in Phase A**:
either restore an actual accurate lineage comment (e.g. "modeled on the same exit-2/stderr blocking
technique documented in the header above" — self-referential, since the technique is now fully
documented in this file's own header) or simply delete the sentence. Recommend deleting it and
replacing with a one-line pointer to the technique's own rationale already present two lines below
("blocks via exit code 2 + a stderr message (NOT `permissionDecision: deny`...)"), since that
rationale is now fully self-contained in this file and does not need an external lineage claim.

### Finding 5 — `commands/README.md` has no per-command table; the absorbed text's "add a row" instruction needs correction

The absorbed former-task-225 text (Phase B scope) says to "add a row to `commands/README.md`."
Direct read of `commands/README.md` (25 lines) shows it is a short prose description of the
`.claude/commands/` directory's provenance and its relationship to `.opencode/commands/` — it
contains **no command-by-command table** to add a row to. The per-command table referenced
elsewhere in the dispatch (`/merge` and `/tag` marked "(user-only)") lives in
`merge-sources/claudemd.md`'s Command Reference table (the one CLAUDE.md-generation source), not
in `commands/README.md`. Recommend the plan phase drop the literal "add a row to
`commands/README.md`" instruction (there is no table there to extend) and confirm the `/please`
row belongs solely in `merge-sources/claudemd.md`'s Command Reference table, consistent with how
`/merge` and `/tag` are already represented there.

### Finding 6 — `user_decision`'s `options` field is a flat array of strings, not AskUserQuestion's richer `{label, description}` objects

`context/standards/user-decision-contract.md`'s field shape is:

```json
{"question": "...", "options": ["Option A — one line", "Option B — one line"], "recommended": "Option A — one line", "blocking": true}
```

— each option is a single string, unlike `AskUserQuestion`'s own native schema
(`context/standards/interactive-selection.md`), which takes `{label, description}` objects per
option. `skill-orchestrate/SKILL.md` Move 4 constructs the actual `AskUserQuestion` call
"(question/options/recommended from `.decision`)" — meaning each `user_decision.options[i]` string
becomes (most plausibly) an `AskUserQuestion` option's `label` with no separate `description`, or
the whole string is split into label+description at render time. This is directly relevant to
Design Question 5's phrasing requirement ("the payload's `options`/`recommended` fields must make
the exact target legible to the user at the moment they answer") — since there is no separate
`description` field to carry supplementary detail in the `user_decision` shape itself, **each
option string must be fully self-describing on its own** (e.g.
`"Push a1b2c3d to origin/feature-x (3 commits ahead, no force)"` rather than a terse label with
detail deferred to a description field that may not survive the Move-4 render). Recommend the
plan phase specify the exact option-string template so the implementation does not under-specify
this.

## Design Questions (from dispatch) — Recommendations

### 1. Grant scope and invalidation predicate

Recommend: **one push only**, task-independent (a push grant is bound to a specific
remote+branch+sha+force-flag, not to the task that requested it — the same grant could
legitimately authorize a push from any dispatch, since what matters is the target, not the
requester). Session-scoped or task-scoped grants are both rejected: session-scoping would let a
single YES cover multiple different pushes across a long-running session (violating "permission
must never be inferred... from a prior approval in another context"); task-scoping is meaningless
once the grant is bound to a specific commit sha anyway (a new commit invalidates it regardless of
task).

**Invalidation predicate** (any ONE of these invalidates a grant, checked at consumption time,
fail-closed on any check failure):
- Age exceeds the expiry window (recommend 600s / 10 minutes, matching the absorbed `/please` text's
  stated window — intentionally wider than the 120s destructive-marker window because `/please` is
  a human-typed, multi-step interactive flow, not an immediately-preceding automated snapshot).
- `git rev-parse HEAD` at consumption time does not match the grant's recorded `HEAD_SHA` (a new
  commit was made since the grant was minted — this closes the "different/later commit" replay
  case named in the dispatch's two-cycle-test requirement).
- The actual push command's target remote or branch does not exactly match the grant's `REMOTE`/
  `BRANCH` fields.
- The actual push command's force-or-not status does not match the grant's `FORCE` field (a grant
  minted for a non-force push must not authorize a force-push of the same branch, and vice versa —
  this is the "a change from non-force to force" case the dispatch names explicitly).
- The grant has already been consumed (deleted on use — no replay of a single grant across two
  pushes).
- The grant's HMAC does not verify against the recorded fields (tamper/corruption).
- The grant file is unreadable, malformed, or missing any required field.

### 2. PR/MR creation and `/merge` — stay fully user-only (argue FOR the working assumption)

Recommend keeping PR/MR creation and `/merge` fully user-only, not extended to the `/please` gate.
Reasoning:
- A push is a single, mechanically bounded, reversible-by-force-push-again action with a precise
  target (remote+branch+sha). A PR/MR is a **social, externally-visible act** (notifies reviewers,
  triggers CI, may auto-close linked issues) whose "undo" is not mechanically equivalent to undoing
  a push — closing a PR does not undo the notifications, CI runs, or review requests already sent.
- `/merge` already has a rich, purpose-built interactive flow (platform detection, draft/label/
  reviewer flags, its own push-then-create sequencing) that assumes **it** performs the push as
  part of a larger user-invoked action; retrofitting the `/please` grant into that flow would mean
  two different consent mechanisms for the same underlying push, which is more complex than the
  current clean separation ("user runs `/merge` directly" is already exactly analogous to a manual
  `/please` grant, just command-specific).
- The dispatch's own "the narrow case being opened" framing supports this: opening exactly one
  narrow gate (push) rather than two (push + PR creation) at once keeps the security-critical
  integrity design (mint path, HMAC, guard) reviewable as a single well-scoped change.

### 3. Categorical exclusions — force-push and pushes to master, outside ANY grant (argue FOR)

Recommend: yes, both are categorically excluded, with no `/please` phrasing able to admit them,
**except** that `--force-with-lease=<ref>:<observed-remote-sha>` (the safe form the absorbed
`/please` text itself names as preferred over bare `--force`) may be admitted **only** for a
non-default branch, never for master. Reasoning:
- `rules/git-workflow.md` already singles out `git push --force` to main/master as a "Never Run"
  bullet, independent of this task — narrowing the *general* push prohibition must not
  simultaneously narrow that stronger, pre-existing, more specific prohibition. The categorical
  exclusion preserves that ordering (specific rule wins over the newly-narrowed general one).
- A force-push to the repo's own default branch is the single most destructive git operation this
  system can perform on shared history for every other clone; no per-invocation human consent
  changes the blast radius or the difficulty of recovery for anyone else who has already pulled
  master.
- `--force-with-lease` on a **non-default** branch is meaningfully safer (it refuses if the remote
  moved since the operator's last observation, closing the "someone else pushed in the meantime"
  race) and the absorbed text explicitly prefers it — so admitting it (never bare `--force`) for
  non-default branches under a specific grant is consistent with "prefer safe forms" while still
  keeping master categorically untouchable.

### 4. Where the gate lives — enforcement pair design

Two new/modified enforcement points, both `exit 2` + stderr (never `permissionDecision: deny`,
per the documented Claude Code bugs already cited in `guard-destructive-git.sh`'s own header):

- **`hooks/guard-git-push.sh` (new)**: `PreToolUse`/`Bash` matcher. Parses `tool_input.command`
  the same way `guard-destructive-git.sh` does (quote/comment-stripped `COMMAND_SCAN`), detects any
  `git push` invocation (bare, `--force`, `--force-with-lease`, `-u`/`--set-upstream`, all forms),
  extracts the target remote/branch/force-flag from the command's own argv (falling back to the
  current branch's configured upstream when the command omits an explicit remote/branch, exactly
  as bare `git push` does), and either finds a valid, matching, unconsumed grant (consumes it,
  exits 0, appends the audit event) or blocks with `exit 2` naming the sanctioned `/please` path.
  Categorical exclusions (Design Question 3) are checked **before** grant lookup — a force-push to
  master is blocked outright, never even reaching "does a grant match this."
- **`hooks/guard-destructive-git.sh` (extended)**: per the absorbed text's item (5), a grant check
  is added for the matched-action-class case, consuming a grant the same way, without changing
  existing no-grant behavior (still blocked exactly as today when no grant exists). Recommend
  placing this grant check **after** the existing dirty-tree early-exit and **after** the
  concurrency-gated history-rewrite predicate (both existing gates stay first, unchanged in
  ordering) — a grant should only ever be *consulted* once the hook has already determined the
  command would otherwise be blocked, mirroring exactly where the existing snapshot-marker check
  sits today (after `MATCHED=1`, just before the final `BLOCKED` exit). This keeps the new grant
  path a pure addition at the same structural point the marker-freshness check already occupies,
  minimizing risk of interacting with task 139's history-rewrite predicate (which runs earlier and
  independently, and has no grant exemption per this task's own file-scope notes elsewhere in the
  dispatch).
- **Registration**: both hooks registered in `root-files/settings.json` (fresh deploys) and
  `merge-sources/settings-hooks.json` (already-initialized repos) per Finding 2 above — a `Bash`
  matcher entry for `guard-git-push.sh` (as its own dedicated single-command matcher object, per
  the idempotency guidance in Finding 2), and a `UserPromptSubmit` entry for the `/please`-mint
  hook (also its own dedicated matcher object).
- **Audit writer**: `scripts/events-append.sh` at two points — grant issuance (`event_type:
  "push_grant_issued"`, `category: milestone`, `--detail-json` carrying remote/branch/sha/force and
  the `/please` request text) and grant consumption/actual push (`event_type: "push_grant_consumed"`,
  `category: success`, same target fields plus the consuming command). Never hand-append to
  `specs/events.jsonl`.

### 5. Durable audit record

Two-event design above (issuance + consumption) is recommended over a single event, because the
dispatch's own two-cycle test needs to distinguish "a grant was issued but never consumed" (run
ends before an answer, or user says NO — no consumption event, issuance event alone is the
complete record of what was asked) from "a grant was issued and consumed" (both events present,
reconstructible end-to-end: what was authorized, when it was asked, when/whether it was used).
`context/formats/events-format.md` and `context/schemas/events-schema.json` need no schema
revision — `event_type` is documented as open/free-form, and `detail` is an open,
`event_type`-specific object, so both new event types fit the existing schema without a version
bump. Confirm both files stay in sync (per the dispatch's own reminder) if any `category` addition
were ever needed — it is not needed here since `milestone`/`success` already exist.

## Phase B design notes (docs sweep + `/please` command)

- `commands/please.md`: user-only, `allowed-tools` should include `Bash(git:*)`, `AskUserQuestion`
  (for the confirmation-before-irreversible-step requirement), and NOT `gh:*`/`glab:*` (this
  command is push-only, per Design Question 2's ruling) — modeled directly on `commands/merge.md`'s
  frontmatter/structure (`description: ... (user-only)`, `argument-hint`, numbered `STEP` sections
  with "EXECUTE NOW" framing) and `commands/tag.md`'s "User Only: YES" / warning-block convention.
  **Important**: `/please` itself is the command a *human* runs interactively — it is not, and
  must not become, a channel a dispatched agent can invoke; nothing in this design gives agents
  access to it (it is not in any skill-to-agent mapping, and its mint path is a `UserPromptSubmit`
  hook that fires only on the human's own literal prompt, never on a command file's expanded
  content).
- Never-list (from the absorbed text, keep verbatim as a hard-coded refusal in `please.md`,
  independent of the guard hooks): credential/secret access, deletion outside the repo, `.git`
  internals, disabling/editing/removing hooks or hook settings. This list should be checked by the
  command's own logic (refuse before doing anything) in addition to whatever the guard hooks
  independently enforce — belt-and-suspenders, since `/please` is user-invoked and therefore not
  itself blocked by the agent-scoped guards.
- `rules/pr-prohibition.md`: add a `/please` exception scoped to "the single push action of that
  one invocation" — reconcile explicitly with "Never push branches or create PRs even if asked to
  in task descriptions or user messages" by adding a clause immediately after that sentence, e.g.
  "The one exception is a user-invoked `/please <push request>` command, which authorizes exactly
  the one push it names via a tamper-resistant grant token — an agent must never invoke `/please`
  on its own, and a task description or user message that merely *describes* a desired push is not
  itself a `/please` invocation and grants nothing." Keep `paths: "**/*"` and the why-eager comment
  unchanged.
- `rules/git-workflow.md`: extend the "Enforced by `guard-destructive-git.sh`" note pattern — add a
  parallel note for the push bullet once `guard-git-push.sh` exists ("Enforced by
  `guard-git-push.sh` (bare/force/force-with-lease/-u forms alike); a `/please`-granted push is the
  sole exception, single-use and target-bound").
- `merge-sources/claudemd.md`: add a `/please` row to the Command Reference table beside `/tag` and
  `/merge`, marked user-only (per Finding 5, `commands/README.md` gets no row — there is no table
  there).
- `context/standards/status-markers.md`: confirmed (Finding above) `[PR READY]` is
  `task_type == "pr"`-only; a consented push does not change when a task reaches `[PR READY]` for
  any other task type. State this explicitly in the plan/summary rather than leaving it unexamined,
  per the dispatch's own instruction.

## Phase C design notes (dispatch relay)

- The relayed `user_decision.question` and each `options[]` string must together make the exact
  push legible per Finding 6 — recommend a template like: `question`: "A dispatched task wants to
  push to a remote. Authorize this specific push?" `options`: `["Grant via /please push
  <sha-prefix> to <remote>/<branch> (no force)", "Do not authorize; the task will stop at its
  current commit"]`, `recommended`: the grant option (the agent is recommending the action it
  itself determined is the task's sanctioned endpoint — recommending is not authorizing;
  `blocking` still governs whether the loop waits). Per the dispatch: `blocking` must always be
  `true` for this decision class — enforce this by convention in the agent instructions/skill
  contract (the agent that emits this `user_decision` sets `blocking: true` unconditionally), since
  a non-blocking path would let the agent proceed on its own recommendation, i.e. authorize its own
  push.
- **The return leg**: per the settled "PATH REVIEW RULING," a YES answer does **not** mint a grant.
  Move 4's relay tells the user (in the `AskUserQuestion` response context, surfaced to the human)
  the exact `/please` line to type — the human then runs `/please push <sha> to <remote>/<branch>`
  themselves, interactively, which is what actually mints the grant via the Phase A hook. This
  closes Finding 2's `.decisions.json` replay hazard **for free**, exactly as the dispatch states:
  nothing replayable is ever written to `.decisions.json` for this question — the recorded
  `{question, answer}` pair (if the loop's Move 4 still appends one for bookkeeping/audit
  parity with every other decision) is inert with respect to authorizing any future push, since the
  guard never reads `.decisions.json` at all; it only reads the grant file `/please` itself writes.
  Recommend explicitly appending a normal `{question, answer: "user was told to run /please
  ...", cycle, timestamp}` entry for audit/history parity with every other decision type (so a
  human reviewing task history sees the exchange happened) — the hazard is specifically about the
  guard treating a *recorded answer* as a *live authorization*, and since the guard never consults
  `.decisions.json`, recording the exchange there is safe by construction. Do not special-case
  `orchestrate-build-dispatch.sh`'s "## Prior Decisions" renderer to skip this entry — since a
  future re-dispatch seeing "the user was told to run /please" in its prior-decisions context is
  informational (the task may still be waiting on the human to actually type it), not itself an
  authorization to push.
- A NO answer and a run-ends-before-answer case: both leave `pending_ask_user` cleared (NO) or
  never populated to begin with (run ends before Move 4 relays it — nothing was asked, nothing
  pending survives past the run since `pending_ask_user` lives in the per-invocation multi-task
  state file, not a durable one) and no grant exists — the guard's default-deny behavior alone
  guarantees no push happens either way, with no special-casing needed in the relay path itself.
- **Two-cycle test**: after a granted-and-consumed push in cycle N (via a human `/please`
  invocation and a subsequent successful `guard-git-push.sh` consumption), cycle N+1's dispatch
  must not carry any residual authorization. Since the grant is single-use (deleted on consumption)
  and bound to the exact `HEAD_SHA` at mint time, this is true by construction the moment any new
  commit is made in cycle N+1 (the old grant's sha no longer matches HEAD, and it was deleted on
  consumption anyway) — the test should assert both independently: (a) the marker file is gone
  immediately after a successful push, and (b) a second `git push` attempt with the same marker
  contents artificially re-written to disk is rejected as "already consumed"/stale, so the
  single-use property is tested directly rather than only via the sha-mismatch side door.
- Whether a granted push may carry across a later cycle in the same run: **no** — the 600s expiry
  window is far shorter than any realistic multi-cycle run, and the sha-binding independently
  invalidates it the moment any further commit happens, which is expected between cycles. This is
  consistent with the companion grant-scope decision (Design Question 1: one push only, bound to
  a specific sha).

## Decisions

- Grant scope: one push only, bound to remote+branch+sha+force-flag; task-independent. (Design
  Question 1, argued above.)
- PR/MR creation and `/merge` remain fully user-only; not folded into the `/please` gate. (Design
  Question 2, argued for.)
- Force-push and pushes to master are categorically excluded from any grant, with a narrow,
  explicit exception for `--force-with-lease` on non-default branches only. (Design Question 3,
  argued for.)
- Grant storage lives under `specs/.push-grant/` (gitignored via a new top-level `.gitignore`
  pattern), never under `.claude/`, because `.claude/` is wipe-and-regenerate disposable and would
  silently destroy key persistence. (Finding 3.)
- Both new hooks (`guard-git-push.sh` Bash matcher, `/please`-mint UserPromptSubmit matcher) must
  be registered in both `root-files/settings.json` and `merge-sources/settings-hooks.json`, each as
  its own dedicated single-command matcher object. (Finding 2.)
- A YES in the Phase C relay never mints a grant directly; it only tells the human the `/please`
  line to type. This is the ruling already settled in the dispatch text and this report confirms
  it is the only clean way to close the `.decisions.json` replay hazard given the current
  unconditional append/render code paths. (Finding 6 / Phase C notes.)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| A write-capable tool other than Bash/Write/Edit (e.g. a future MCP filesystem-write server) bypasses the grant/key write-guard | Document the guard's exact matcher-coverage scope in the plan; revisit whenever a new write-capable tool is wired into this deploy. Not fully closeable statically — call this out honestly rather than claiming completeness. |
| `guard-destructive-git.sh`'s grant-check addition interacts badly with task 139's history-rewrite predicate ordering | Add the grant check strictly after both existing early-exit points (dirty-tree exit, history-rewrite predicate), mirroring where the snapshot-marker check already sits; do not reorder existing gates. |
| A malformed or partially-written grant file is misread as valid | Fail-closed on every parse step (missing field, non-numeric timestamp, unparseable HMAC) — treat any read/verify failure as "no grant," never as "grant present." |
| The new push guard's argv-parsing has the same quoted-pathspec blind spot `guard-destructive-git.sh` already documents | Accept the same known, documented, symmetric limitation rather than introducing a second, inconsistent quote-handling scheme; state it in the new hook's header exactly as the existing one does. |
| `/please`'s never-list is enforced only in the command's own prompt logic, not mechanically | Acceptable per the absorbed design (the command is user-invoked, not agent-invoked, so the guard hooks' job is to stop *agents*; the never-list is a belt-and-suspenders human-facing safeguard, not a second mechanical gate) — but state this scoping explicitly in `please.md` itself so a future reader does not assume it is hook-enforced. |

## Context Extension Recommendations

- **Topic**: Install-once vs. merge-fragment settings registration.
  **Gap**: `context/patterns/regeneration-is-manual-only.md` documents the *mechanism* but there is
  no single checklist a future hook-adding change can follow to confirm both files were updated
  consistently (this task's own research had to cross-reference two files by hand to find the
  `guard-destructive-git.sh` gap).
  **Recommendation**: consider a new `check-extension-docs.sh` Rule (mirroring Rule H's
  `provides.rules`-registration check) that asserts every `PreToolUse`/`UserPromptSubmit` hook
  filename referenced in `root-files/settings.json` also appears somewhere in
  `merge-sources/settings-hooks.json` (or is explicitly allow-listed as install-once-only with a
  stated reason) — this is a structural lint in the same spirit as Rule H's own motivating case,
  and would have caught `guard-destructive-git.sh`'s own gap. Out of scope to implement in this
  task, but worth naming for a follow-up.

## Appendix

### Search queries / reads performed

- Full read of `hooks/guard-destructive-git.sh` (469 lines).
- `scripts/git-snapshot.sh` marker-write section (lines 395-534) and header comment block.
- `scripts/git-commit-scoped.sh` header/usage/mutex-acquire sections (lines 1-180, 330-360).
- `manifest.json` `provides.hooks` and `provides.rules` arrays (via `python3 -c` JSON parse).
- `root-files/settings.json` full `hooks` object; `merge-sources/settings-hooks.json` full content;
  cross-diffed against this repo's own deployed `.claude/settings.json`.
- `context/patterns/regeneration-is-manual-only.md` "Merge Semantics That Regeneration Cannot Fix"
  section.
- `context/standards/interactive-selection.md` (full file) and `context/standards/
  user-decision-contract.md` (full file).
- `context/formats/return-metadata-file.md`'s `user_decision` subsection.
- `docs/architecture/handoff-schema.md`'s "Decisions File Schema" section.
- `scripts/orchestrate-cycle-postflight.sh` grep for `user_decision`/`ask_user`/`pending_ask_user`
  and the surrounding relay code (lines ~1133-1160, ~1457-1472).
- `scripts/orchestrate-build-dispatch.sh` grep for `Prior Decisions`/`decisions.json`, plus the two
  concrete code sections (lines ~380-393, ~535-552).
- `skills/skill-orchestrate/SKILL.md` full-file byte count (19983 B, confirmed against the
  dispatch's stated 17-byte headroom under the 20000 B ceiling) and Move 3/Move 4 sections
  (lines ~195-270).
- `commands/merge.md` (first 220 lines) and `commands/tag.md` (header) as the `/please` structural
  model.
- `commands/README.md` (full file, 25 lines) — confirmed no per-command table exists there.
- `scripts/events-append.sh` usage block and `context/formats/events-format.md` category-enum
  section.
- `context/standards/status-markers.md` grep for `PR READY`.
- `scripts/check-extension-docs.sh` Rule H (`check_undeclared_rules`) implementation.
- `scripts/tests/test-guard-destructive-git.sh` fixture-driven style (first 80 lines + line count)
  as the model for new `test-guard-git-push.sh`/`test-please-grant.sh`.
- Repo-wide `find`/`grep` confirming no `please*`, `push-grant*`, `guard-git-push*`, or
  `.decisions.json` files exist yet anywhere in the source store or `specs/` (net-new, no partial
  prior implementation to reconcile with).
- `/home/benjamin/.config/nvim/.gitignore` full read, and confirmation via `manifest.json` that it
  is deployed through `provides.root_files`.
- `specs/state.json` lookup for task 263's own recorded `file_scope`, dependencies (`[139]`), and
  confirmation that dependency task 139 is completed/archived
  (`specs/archive/139_forbid_concurrent_writer_history_rewrites`).
