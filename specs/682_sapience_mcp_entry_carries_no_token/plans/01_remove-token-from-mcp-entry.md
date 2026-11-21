# Implementation Plan: Stop writing the Sapience token into the per-project MCP entry

- **Task**: 682 - Stop writing the Sapience token into the per-project MCP entry in ~/.claude.json
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/682_sapience_mcp_entry_carries_no_token/reports/01_remove-token-from-mcp-entry.md
- **Artifacts**: plans/01_remove-token-from-mcp-entry.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The per-project MCP entry `~/.claude.json` carries for each registered repository embeds the raw
Sapience bearer token in `env.SAPIENCE_TOKEN`, once per project, because
`setup-sapience-mcp.sh`'s `generate_sapience_config()` appends that key whenever
`~/.sapience/config.json` holds a resolvable token. The vendor payload never needs it there: a
single module-level statement in `~/.sapience/mcp.py` resolves the token from `config.json` when
the variable is unset, and it runs before any CLI-flag dispatch, so every invocation shape the
entry reaches shares it. This plan removes the token from the written entry, inverts the
verifier so a token-bearing entry becomes the defect, adds the regression test and its negative
control, documents the token's durable homes and the copy boundary, and migrates the already
registered entries in place.

Definition of done: no project entry in `~/.claude.json` holds a value equal to the configured
token; the MCP server still authenticates with `SAPIENCE_TOKEN` absent from its environment; and
`verify-sapience-mcp.sh` fails on a token-bearing entry, naming the remedy.

### Premise Re-Validation

Every carried figure in the dispatch description was checked against live state and against the
research report before this plan was written. Result, stated explicitly even where it only
confirms the description:

| Description claim | Live check | Result |
|---|---|---|
| `setup-sapience-mcp.sh` builds the entry with `env {SAPIENCE_HOST, SAPIENCE_TOKEN}` whenever a token is resolvable | read `generate_sapience_config()` and `resolve_token()` | **CONFIRMED** — the `(if ($token \| length) > 0 then { SAPIENCE_TOKEN: $token } else {} end)` branch is live; `resolve_token()` reads `config.json`'s `.token` |
| the raw token is copied in plaintext into `~/.claude.json` once per registered project | counted project entries carrying the key | **CONFIRMED, and quantified**: 6 of 6 project-scoped sapience entries carry `env.SAPIENCE_TOKEN` |
| `mcp.py` falls back to `~/.sapience/config.json` when `SAPIENCE_TOKEN` is unset | read the single module-level `TOKEN = os.environ.get('SAPIENCE_TOKEN') or _CFG.get('token') or ''` statement | **CONFIRMED** — one shared statement, evaluated at import, before `sys.argv` dispatch; all four named shapes share it |
| `config.json` is mode 0600 | `ls -la ~/.sapience/config.json` | **CONFIRMED** — `-rw-------` |
| the script already supports an entry with no token | read the `else {}` branch and the suite's existing Case 7 | **CONFIRMED** — token-absent is already an exercised shape |
| build item (2)'s conditional ("if one does not, keep the variable only for that case") | measured in Phase 1 below, not assumed | **PENDING PHASE 1** — research found no divergent path; Phase 1 confirms mechanically rather than by reading |

One figure in the description's framing needs a correction that changes what the fix buys, so it
is stated here rather than left implicit: `~/.claude.json` is itself mode `0600`, so the exposure
this task closes is **not** world-readability. It is that the token is printed by any
`jq .projects[...]` or `claude mcp get` inspection and thereby enters a session transcript that
the capture path may extract — which the description already says, and which remains true.

### Research Integration

The research report settles build item (1) by inspection and establishes four facts this plan
builds on directly: (a) `mcp.py`'s token resolution is one shared module-level line, so no
invocation shape diverges and item (2) has no "else" branch to design for; (b)
`process_write()`'s existing whole-entry comparison and replacement already migrates a
token-bearing entry wholesale the first time the changed writer runs, so **no new migration code
is needed** and the hook needs no edit; (c) `verify-sapience-mcp.sh` check (b) today *expects*
the token whenever `config.json` holds one, so the fix is an inversion, not an addition; (d) the
existing suite's Case 7 covers only the token-absent-in-`config.json` branch, leaving the
branch that actually matters uncovered.

Two research findings are carried forward without being acted on here: the orphaned
`sapience-register-mcp` wrapper in `~/.dotfiles/packages/sapience-flake/lib/wrappers.nix` (a
different repository, unreachable from any applied module) and `mcp.py`'s `registered_tokens()`
diagnostic, which reads the already-retired top-level entry and is unaffected by this change.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided to this dispatch.

## Goals & Non-Goals

**Goals**:
- The writer emits `env: { SAPIENCE_HOST: <host> }` unconditionally, with no token key, at every scope.
- Already-registered entries migrate in place, idempotently, with no new migration code.
- `verify-sapience-mcp.sh` check (b) fails a token-bearing entry and names the remedy.
- A regression test asserts no value in a written entry equals the configured token, with a negative control proving the assertion discriminates.
- `per-repo-scoping.md` states where the token lives, who owns each location, and where it must never be copied.
- Every on-machine token location is enumerated and confirmed non-world-readable and uncommitted.

**Non-Goals**:
- Editing `~/.sapience/mcp.py` or any vendor payload file. It is mutable, self-updating vendor state and is read-only input throughout.
- Editing `hooks/sapience-mcp-register-project.sh`. It already invokes the writer unconditionally on every session start for an active repo; the migration rides on that existing call.
- Fixing the orphaned `~/.dotfiles` `sapience-register-mcp` wrapper. Different repository, no applied call path, out of territory.
- Removing the token from `~/.sapience/config.json` or `/run/secrets/sapience_token`. Those are the token's intended homes.
- Rotating the token. If the user judges the historical plaintext exposure to warrant rotation, that is their decision and a separate action.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Sibling task 683 declares an **identical** five-file `file_scope` and is in `planning` this same cycle | H | H | Serialization is the orchestrator's admission gate's job, but the implementer must still re-read each of the five files immediately before editing, stage only this task's own hunks, and stop and report any foreign modification. Named again per phase below. |
| The MCP client may *replace* rather than overlay the spawn environment, so the entry's `env` is all the server gets | M | L | `mcp.py` resolves `config.json` via `os.path.expanduser('~')`, which falls back to the passwd database with `HOME` unset. Phase 1 makes this mechanical rather than inferred by invoking under `env -i`. |
| The live writer is `$HOME/.claude/scripts/setup-sapience-mcp.sh`, a user-level copy the installer places — **not** this repo's deployed `.claude/` tree | H | H | A source-store edit alone does not reach production. Phase 5 re-runs `install-sapience-mcp-session-hook.sh` **from the source store** (its `WRITER_SRC` is `$SCRIPT_DIR/setup-sapience-mcp.sh`, so it copies the edited file directly) before any migration step. |
| Only the current repo is re-registered per session, so a single SessionStart migrates one of six entries | M | H | Phase 5 drives the writer explicitly over every registered project path rather than waiting for six sessions. |
| A `~/.claude.json` backup taken before migration itself contains the token in plaintext | M | M | Phase 5 takes the backup at `0600`, verifies, then removes it in the same phase — the backup never outlives the phase that needs it. |
| A whole-tree redeploy in Phase 5 regenerates the deployed tree from a source store sibling 683 may be mid-edit in | M | M | Declared honestly via the `__WHOLE_TREE__` sentinel so the admission gate can serialize; the implementer re-checks `git status` for foreign modifications immediately before invoking the deploy script and stops if any are present. |
| Test case numbering collides if 683 lands new cases first | L | M | Phase 3 re-reads the header manifest immediately beforehand and takes the next free numbers rather than the ones this plan names. |

## Decisions

- **The hook is not edited.** Build item (2) asks for existing entries to migrate "in place on the next SessionStart registration, idempotently." That behavior already exists and needs no code: `process_write()` compares the existing entry to the canonical entry *as a whole* and replaces it wholesale on any divergence, and the SessionStart hook already calls the writer unconditionally for an active repo. Adding migration logic would duplicate a mechanism that is already correct. The hook stays in the task's territory (it is the call path the migration rides on) but out of its edit set.
- **The writer and the verifier move together as one atomic batch.** Between a writer that no longer emits the token and a verifier that still expects one whenever `config.json` holds a token, a live `verify-sapience-mcp.sh` run on this machine would fail. The two files jointly define "the canonical shape," so Phase 2 declares `Commit Mode: atomic-batch` rather than committing them separately.
- **`resolve_token()` is deleted outright, not left unused.** Nothing else in `setup-sapience-mcp.sh` consumes `$TOKEN`. Leaving a dead resolver invites exactly the regression the new test exists to catch.
- **Build item (2)'s "else" branch is not designed for speculatively.** Research found no `mcp.py` code path requiring the environment variable, so the plan commits to the unconditional form and treats Phase 1 as the confirming measurement. If Phase 1 contradicts that, Phase 2's first task is to narrow the change and say which path diverged — written into the record, not silently absorbed.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Measure mcp.py token resolution with SAPIENCE_TOKEN unset [COMPLETED]

**Goal**: Establish mechanically — not by reading the source — that each of the four invocation
shapes the MCP entry reaches resolves the token from `~/.sapience/config.json` with
`SAPIENCE_TOKEN` absent from the environment, and record any shape that does not.

**Tasks**:
- [x] Capture the resolved token's length and a short fingerprint (never the value) from `~/.sapience/config.json` so later assertions can compare without printing the secret. *(completed: length 16, sha256[:12]=1ccd05e02475)*
- [x] Invoke each shape with the variable stripped, using an absolute interpreter path so no `PATH` is needed: `env -i HOME="$HOME" /usr/bin/env python3 ~/.sapience/mcp.py --briefing-text`, `... --receipt`, `... --effect-line`, and `... --statusline` as the cheap authentication probe (it prints `sapience: set token` exactly when `TOKEN` is empty). Resolve the absolute `python3` path once up front rather than assuming `/usr/bin/python3`. *(completed: all four PASS)*
- [x] Exercise the bare stdio server shape the entry's `command`/`args` actually spawn: pipe one `initialize` JSON-RPC line on stdin under the same stripped environment and confirm a `result` reply rather than the `Set SAPIENCE_TOKEN` stderr message and `exit 1` that the `if not TOKEN:` guard produces. *(completed: PASS, well-formed result reply)*
- [x] Write the per-shape outcome to `specs/682_sapience_mcp_entry_carries_no_token/records/01_mcp-token-resolution-measurement.md`: the command run, the observed result, and a verdict line per shape. Record the token only as length plus fingerprint. *(completed)*
- [x] If any shape fails, state in that record which one and why, and note that Phase 2 must keep `SAPIENCE_TOKEN` for that case alone. If all pass, state that build item (2) applies unconditionally. *(completed: all 5 probes PASS; build item (2) applies unconditionally)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Four named invocation shapes plus the bare stdio server (five probes), and one new record file as the phase's only edit. Confirm by running all five probes before writing the record; if a sixth reachable shape surfaces, add it to the record rather than omitting it.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` as its entire output for this phase's one touched path, which lies under `specs/**` and is not a report/plan/summary artifact, so the `prose` row's diff read-through is the honest covering check.

**Files to modify**:
- `specs/682_sapience_mcp_entry_carries_no_token/records/01_mcp-token-resolution-measurement.md` - new; the per-shape measurement record

**Verification**:
- The record file exists, is non-empty, and carries a verdict line for all five probes.
- Diff read-through confirms the phase changed nothing but that one prose file.
- No probe's output, and nothing in the record, contains the token value.

---

### Phase 2: Writer emits a token-free entry; verifier refuses a token-bearing one [NOT STARTED]

**Goal**: Make "no token in the entry" the canonical shape on both sides at once — the writer
stops emitting it, and check (b) starts failing it with a named remedy.

**Tasks**:
- [ ] Re-read both files immediately beforehand (sibling 683 declares the identical file set); stop and report if either carries a foreign modification.
- [ ] If Phase 1's record flagged a diverging shape, narrow this phase's change to keep `SAPIENCE_TOKEN` for that case only, and say which in the commit message. Otherwise proceed unconditionally.
- [ ] In `generate_sapience_config()`, drop the `--arg token "$TOKEN"` plumbing and the `(if ($token | length) > 0 then { SAPIENCE_TOKEN: $token } else {} end)` branch so `env` is always exactly `{ SAPIENCE_HOST: $host }`.
- [ ] Delete `resolve_token()` and its `TOKEN="$(resolve_token)"` call site; confirm by grep that no other reference to `$TOKEN` or `resolve_token` remains in the script.
- [ ] Update the script's own header/comment text where it describes the entry as carrying a token, so the file does not document a shape it no longer writes.
- [ ] In check (b), replace the `config.json`-token-presence branch that sets `EXPECTED_HAS_TOKEN=true` with a constant `false`, and drop the now-unused `CFG_TOKEN` read.
- [ ] Reword the mismatch message for this dimension so a token-bearing entry reads as the defect and names the remedy, e.g. `entry carries env.SAPIENCE_TOKEN; remedy: re-run setup-sapience-mcp.sh --scope project to replace it with the token-free canonical shape`.
- [ ] Confirm the idempotent-migration claim rather than assuming it: in a throwaway `HOME` fixture, hand-write a token-bearing entry, run the changed writer once, and assert the entry is token-free; run it a second time and assert the file is byte-identical.
- [ ] Commit both files as one atomic batch.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: Two files; roughly one deleted `jq` branch plus one deleted 11-line function in the writer, and a two-line expectation inversion plus one reworded message in the verifier. Confirm against the actual diff — if the change exceeds that shape, say so in the phase's commit message rather than widening silently.

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` selects `test-sapience-mcp-registration.sh`, the one suite covering both files, and no externally visible signature changes.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` - drop the conditional token branch and its jq argument plumbing; delete the token resolver function and its call site; correct the header text
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - check (b): `EXPECTED_HAS_TOKEN` becomes a constant `false`; reword the mismatch message to name token presence as the defect and give the remedy

**Verification**:
- `bash .claude/scripts/verify-touched.sh <the two paths above>` runs `test-sapience-mcp-registration.sh` green. Existing Cases 1, 2, 3, 7, 20 and 22 must all still pass — Case 20's all-green fixture uses a tokenless `config.json`, so it is expected to be unaffected; a failure there is a real regression, not fixture drift.
- `grep -c 'SAPIENCE_TOKEN' agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` returns 0 (or, on the narrowed path, exactly the one retained case, named in the record).
- The hand-built token-bearing fixture entry is rewritten token-free on the first run and byte-identical on the second.
- A token-bearing fixture entry fails the changed verifier with exit 1 and a `[FAIL] (b)` line naming the remedy.

---

### Phase 3: Regression test with negative control [NOT STARTED]

**Goal**: Pin "a registered entry contains no value equal to the configured token" so a future
edit reintroducing it fails loudly, and prove the assertion discriminates rather than passing
vacuously.

**Tasks**:
- [ ] Re-read the suite and its header manifest immediately beforehand. This plan observed case numbers running 1-53; take the next free numbers from what the file actually shows, not the ones named here, in case sibling 683 has already appended cases.
- [ ] Add the positive case: a fixture `HOME` whose `~/.sapience/config.json` carries a known sentinel token value, run the writer `--scope project`, then assert via a whole-entry scan (`jq -r '.. | strings' <entry>` or equivalent, not only `env.SAPIENCE_TOKEN`) that the sentinel appears nowhere in the written entry. Scanning the whole entry rather than one key is the point: it still catches a future change that relocates the token to a different field.
- [ ] Add the negative control: hand-build a `~/.claude.json` entry that **does** embed the sentinel, and assert it is correctly flagged — by the writer's own existing-entry comparison judging it divergent and replacing it, and by `verify-sapience-mcp.sh` exiting 1 with a `[FAIL] (b)` line. A positive assertion that cannot fail is not coverage.
- [ ] Assert the failure message names a remedy, so the regression is actionable and not merely detected.
- [ ] Extend the header-comment case manifest with the new case numbers and one-line descriptions, following the file's existing convention.
- [ ] Run the whole suite, not only the new cases.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: Two new cases appended to one file, numbered after the suite's current highest (observed as 53). Confirm by re-reading the manifest at phase start; if the highest has moved, renumber rather than collide.

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` selects `test-sapience-mcp-registration.sh` and `test-sapience-publish.sh`, and the edit adds test cases without touching any production symbol.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - two new cases (token-never-written, plus its negative control) and the matching header-manifest entries

**Verification**:
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` is green, with the full suite run and both new cases reported as passing.
- Temporarily reverting Phase 2's writer change makes the new positive case FAIL — the assertion is proven live, not assumed. Restore the change immediately afterward and confirm green again before committing.
- The negative control fails the verifier with exit 1 and a `[FAIL] (b)` line.

---

### Phase 4: Document the token's homes and the copy boundary [NOT STARTED]

**Goal**: State in `per-repo-scoping.md` where the token durably lives, who owns each location,
and that it must never be copied into `~/.claude.json` at any scope — and back that with a
verified inventory of every place the token is written on this machine.

**Tasks**:
- [ ] Re-read the doc immediately beforehand (sibling 683 declares it too); stop and report any foreign modification.
- [ ] Re-verify each location's mode and ownership rather than carrying the research report's figures forward: `/run/secrets/sapience_token` (observed `-r--------`, sops-nix), `~/.sapience/config.json` (observed `-rw-------`, vendor payload) and its `.bak-*` siblings, `~/.config/sf1-hub-ben/env` and `~/.config/sf1-hub-ben/sapience-token` (both observed `-rw-------`).
- [ ] Compare by **value**, not by filename, which of those files actually hold the Sapience bearer token. `~/.config/sf1-hub-ben/sapience-token` is 17 bytes against `/run/secrets/sapience_token`'s 43, so it is probably a different credential for a different subsystem — state what the comparison shows rather than assuming the name implies the value.
- [ ] Confirm no plaintext copy is committed anywhere: the one git-tracked artifact is `~/.dotfiles/secrets/secrets.yaml`, sops-encrypted. Re-check rather than assert.
- [ ] Add a named subsection to the doc — after "The MCP-Registration Triad" or as a numbered Hazards entry, matching whichever the surrounding text reads better with — stating: the token's durable homes and each one's owner (`~/.dotfiles` owns the sops secret; the vendor payload / bootstrap owns `config.json`); that `mcp.py` resolves it from `config.json` with the variable unset, via one shared module-level statement; and that it must never be copied into `~/.claude.json` at any scope, because that file is routinely inspected in plaintext (`jq .projects[...]`, `claude mcp get`) and is within reach of Sapience's own transcript-capture path, so a copy there is a secret that can round-trip into the vault it authenticates against.
- [ ] Name the enforcing surfaces in the same subsection — the writer's unconditional token-free `env`, check (b)'s refusal, and the regression case — so a future reader sees where the boundary is held, not only that it exists.
- [ ] State the token's locations and owners without quoting any token value or fragment.
- [ ] Note the orphaned `~/.dotfiles` `sapience-register-mcp` wrapper as a one-line latent hazard, naming `~/.dotfiles` as the owner and that no applied module path reaches it today.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: One doc subsection plus the `index-entries.json` `line_count` it moves; four candidate token locations to inventory, of which the value comparison may show fewer than four actually hold this token. Confirm the location set by running the checks before writing the subsection, and record what the comparison actually showed.

**Tier Justification**: `bash .claude/scripts/verify-touched.sh agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md agent-system/extensions/sapience/index-entries.json` selects `test-context-reachability.sh`, `test-deploy-orphans.sh`, `test-index-entries-schema.sh`, `test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`, and `test-roadmap-command-registration.sh`, which together cover a prose-plus-index-metadata edit with no executable surface.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - new subsection: the token's durable homes, each one's owner, the resolution path, and the never-copy boundary with its enforcing surfaces
- `agent-system/extensions/sapience/index-entries.json` - the coupled generated surface: this file's `line_count` for `project/sapience/domain/per-repo-scoping.md` (observed `410`) moves with the edit above; `check-extension-docs.sh` Rule R reads it and it is not commit-blocking in this repository (no `pre-commit` hook is installed), so the declaration is owed here while the regeneration itself lands in Phase 5's redeploy

**Verification**:
- `bash .claude/scripts/verify-touched.sh <the two paths above>` is green.
- The new subsection names every location the inventory actually confirmed, each with its owner, and contains no token value or fragment: `grep -c "$(jq -r .token ~/.sapience/config.json)" <doc>` returns 0.
- Every inventoried location re-checked as non-world-readable, and the committed artifact confirmed sops-encrypted.

---

### Phase 5: Migrate the live entries and verify end to end [NOT STARTED]

**Goal**: Reach the task's done condition on the real machine: no project entry in
`~/.claude.json` holds the token, the MCP server still authenticates, and the verifier fails on
a regression.

**Tasks**:
- [ ] Re-check `git status --short` for foreign modifications from sibling 683 before any whole-tree action; stop and report rather than proceeding if any are present.
- [ ] Re-run `bash agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh --dry-run` first, then without the flag, **from the source store**, so the edited writer reaches `$HOME/.claude/scripts/setup-sapience-mcp.sh` — the copy the SessionStart hook actually invokes. A source-store edit alone does not reach production.
- [ ] Back up `~/.claude.json` to a `0600` file before mutating it, noting that the backup contains the token in plaintext and must not outlive this phase.
- [ ] Enumerate every project path whose entry carries `env.SAPIENCE_TOKEN` (observed: 6 of 6 project-scoped sapience entries) and drive the installed writer over each with `--scope project --project <path>`, rather than waiting for six separate SessionStart registrations.
- [ ] Assert the done condition by value, not by key: no string anywhere under `.projects` in `~/.claude.json` equals the configured token, and no entry has an `env.SAPIENCE_TOKEN` key.
- [ ] Confirm the server still authenticates with the variable absent: the stripped-environment `--statusline` probe prints a real line rather than `sapience: set token`, and the stdio `initialize` handshake returns a `result`. Re-run the Phase 1 probes against the post-migration state rather than trusting the pre-migration measurement.
- [ ] Run `verify-sapience-mcp.sh` against this repository and confirm check (b) passes on the real, now token-free entry.
- [ ] Confirm the verifier fails on a regression: reintroduce the token into one throwaway fixture entry and confirm exit 1 with a `[FAIL] (b)` line naming the remedy.
- [ ] Remove the `~/.claude.json` backup once the above all pass, and confirm it is gone.
- [ ] Redeploy so the deployed tree stops diverging from the edited source store (the dispatch reports `.claude/` as stale for the sapience extension), which also auto-repairs Phase 4's `index-entries.json` `line_count`: `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked with the Bash tool's `timeout` raised to 600000 per the bounded-wait idiom.
- [ ] Record the completion of each item (1)-(6) against its evidence, including item (6)'s inventory result.

**Timing**: 1 hour

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Scope Hypothesis**: Six project entries to migrate, derived from the live count observed while planning. Re-enumerate at phase start rather than trusting six — the count moves whenever a repository is registered or reaped — and migrate whatever the enumeration returns.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, which regenerates the entire deployed tree; declared via the reserved sentinel rather than by naming any `.claude/**` path
- `agent-system/extensions/sapience/index-entries.json` - reconciled by the redeploy above (Phase 4 declared and moved the `line_count`; this phase regenerates it)

**Verification**:
- Scoped touched-path check for this dispatch's own in-dispatch obligation: `bash .claude/scripts/verify-touched.sh` with no arguments, deriving this dispatch's touched paths itself.
- The complete gate set is **deferred to the orchestration close** (the once-per-invocation batch gate stage), not invoked independently here. Under a standalone, non-orchestrated run with no such close, run `bash .claude/scripts/verify-deploy.sh` directly instead.
- `jq` over `~/.claude.json` confirms zero project entries carry `env.SAPIENCE_TOKEN` and zero strings under `.projects` equal the configured token.
- The stripped-environment `--statusline` probe and the stdio `initialize` handshake both succeed post-migration.
- `verify-sapience-mcp.sh` exits 0 against this repository, and exits 1 with a `[FAIL] (b)` line against the regression fixture.
- The plaintext backup of `~/.claude.json` no longer exists.

---

## Testing & Validation

- [ ] All five Phase 1 probes resolve the token from `config.json` with `SAPIENCE_TOKEN` unset, recorded per shape.
- [ ] `test-sapience-mcp-registration.sh` passes in full, including existing Cases 1, 2, 3, 7, 20, 22 and both new cases.
- [ ] The new positive case fails when Phase 2's writer change is temporarily reverted, proving it discriminates.
- [ ] The negative control fails the verifier with exit 1 and a named remedy.
- [ ] A hand-built token-bearing entry is rewritten token-free on the first writer run and byte-identical on the second.
- [ ] No project entry in `~/.claude.json` holds a value equal to the configured token.
- [ ] The MCP server authenticates with the variable absent from its environment.
- [ ] No deliverable file contains the token value or any fragment of it.
- [ ] Scoped touched-path check green; complete gate set discharged at the orchestration close.

## Artifacts & Outputs

- `specs/682_sapience_mcp_entry_carries_no_token/plans/01_remove-token-from-mcp-entry.md` (this plan)
- `specs/682_sapience_mcp_entry_carries_no_token/records/01_mcp-token-resolution-measurement.md` (Phase 1)
- `specs/682_sapience_mcp_entry_carries_no_token/summaries/01_remove-token-from-mcp-entry-summary.md` (on completion)
- Edited: `scripts/setup-sapience-mcp.sh`, `scripts/verify-sapience-mcp.sh`, `scripts/tests/test-sapience-mcp-registration.sh`, `context/project/sapience/domain/per-repo-scoping.md`, `index-entries.json` — all under `agent-system/extensions/sapience/`
- Mutated outside the repository: `~/.claude.json`'s project-scoped sapience entries, `$HOME/.claude/scripts/setup-sapience-mcp.sh`, `$HOME/.claude/hooks/sapience-mcp-register-project.sh`

## Rollback/Contingency

Two rollback surfaces, because one of them is outside the repository and git does not cover it.

**In-repo (the five source-store files).** If a phase must be reverted after it committed, follow
`context/contracts/recovery.md`'s rollback rung for the exact `git-snapshot.sh` invocation shape,
including its out-of-scope override flag for a deliberately whole-tree case, and run the rollback
only after that snapshot. Never emit a bare reverting `git-snapshot.sh` as a routine
start-of-phase precaution; an ordinary defensive checkpoint before the Phase 5 live mutation uses
`--no-revert`, which is durable without touching the working tree. Phase 2's two files are an
atomic batch and revert together.

**Out-of-repo (`~/.claude.json` and the installed user-level copies).** Phase 5's `0600` backup is
the rollback for the live config, which is why it is taken before the first mutation and removed
only after verification passes. If the migration must be undone after the backup is gone, the
writer itself is the recovery path: restore the previous writer (`git checkout` the pre-change
revision of `scripts/setup-sapience-mcp.sh` into a scratch location, never over the working
tree), re-run the installer from there, and re-register the affected projects — the entry is
rebuilt from `config.json`, which still holds the token, so nothing is unrecoverable.

**Contingency if Phase 1 contradicts the research.** If any invocation shape genuinely requires
`SAPIENCE_TOKEN`, Phase 2 narrows to keep the key for that case alone, Phase 3's positive case
narrows to the shapes that do not need it, Phase 4 documents the exception explicitly, and Phase
5's done condition becomes "no entry holds the token except the one documented case." The plan
does not silently absorb that outcome: it is written into Phase 1's record and named in the
summary.
