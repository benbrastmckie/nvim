# Implementation Plan: Task #676

- **Task**: 676 - Tag transcript-captured KOs with the repo tag
- **Status**: [COMPLETED]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/676_tag_transcript_captured_kos_with_repo_tag/reports/01_tag-transcript-captured-kos-repo.md
- **Artifacts**: plans/01_tag-pending-kos-repo-tag.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add one new, extension-owned script to the sapience source store that rewrites the `provenance`
field of every still-pending record in `~/.sapience/pending_kos.jsonl`, injecting the literal
`[repo:<slug>]` substring that `sapience-retrieve.sh`'s `/v1/search?source=` filter is the only
thing that matches. The slug is resolved per record by looking the record's `project` value up
against `~/.sapience/config.json`'s `.capture.projects[].name` to get that entry's
`path_prefix`, then resolving that path's git toplevel through the same marker-delimited
`resolve_checkout_toplevel()` block eight existing scripts already share byte-identically, then
taking its basename. The script ships with a fixture-driven test suite, a corrected population
census in the extension's own domain docs, and a redeploy; it does **not** mutate the live
ledger or post anything to the vault, both of which are left to the user (see Risks).

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class figure in the dispatch description was checked against live state at
planning time, not carried forward on the research report's authority:

| Carried claim | Live check | Result |
|---------------|-----------|--------|
| 1260 pending records for nvim | `python3` count over `~/.sapience/pending_kos.jsonl` grouped by `project` | **Confirmed exactly**: `nvim` 1260 (also `.dotfiles` 1687, `sapience-app` 810; 3757 total) |
| Captured KOs carry no `[repo:<slug>]` in `provenance` | same pass, counting records with a non-empty `provenance` key | **Confirmed, stronger**: 0 of 3757 records carry a `provenance` key at all |
| `project: "<name>"` field present | schema inspection of the same file | **Confirmed** |
| Slug resolution must go through `capture.projects[].path_prefix` | `jq '.capture.projects[]'` on `~/.sapience/config.json` | **Confirmed**: 12 entries, 4 enabled (`.dotfiles`, `nvim`, `abood`, `sapience-app`); `nvim` → `/home/benjamin/.config/nvim` |
| No delete/update API for a landed KO | not re-probed live (a probe is a vault call); accepted from the report's exhaustive grep of every vendor HTTP call site | **Carried, not re-verified** — consequence is only that backfill stays out of scope, which costs nothing if wrong |
| 39-vs-4 untagged/tagged search gap | not re-run (a live vault query) | **Carried, not re-verified** — it motivates the task but no phase below depends on the exact figures |

Two figures found in the codebase that the research report did not state, and that this plan
depends on:

- The lockstep guard on the shared `resolve_checkout_toplevel()` block (`Case 30` in
  `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`, lines
  1215-1251) enumerates **eight** files, not the five named in the block's own in-block comment.
  The in-block comment has therefore already drifted from the guard's actual list — and because
  the guard compares the block **byte-for-byte**, that comment must be copied verbatim into any
  ninth copy and must not be "corrected" in one copy alone (Phase 1 risk, below).
- `~/.sapience/extract_local.py`'s `_ledger_lock` class locks `QUEUE.parent / '.ledger.lock'`
  i.e. `~/.sapience/.ledger.lock`, blocking and exclusive via `fcntl.flock`, and `_write_atomic`
  writes `<path>.tmp.<pid>` then `os.replace` with mode `0o600`. These are the exact conventions
  the new script must match.

### Research Integration

The report's four load-bearing findings drive the whole decomposition and are adopted without
modification: (1) the live pipeline on this machine is `extract_local.py`, not `upload.py`, so
the existing "cannot be fixed from this repository" conclusion in the domain docs is written
against a dead code path; (2) `review_queue()` → `_strip_meta()` → `post_kos()` passes every
non-underscore field verbatim to `POST /ingest-kos`, so a `provenance` written into the ledger
between `sapience sync` and `sapience review` reaches the server unchanged; (3) `pending_kos.jsonl`
is a `LEDGER_FILE`, preserved rather than overwritten by `sapience update`, so an
extension-owned script that touches only that file is durable across vendor auto-update;
(4) `_ko_hash()` covers only `subject`/`predicate`/`object_value` and `_group_summary()` prefers
`project` over `provenance`, so the edit is safe against both dedupe and the human review view.
The report's recommendation 3 (no launcher wrapper, because the `sapience` binary is
Nix-profile/`~/.dotfiles`-owned) and recommendation 5 (no backfill design) are adopted as
non-goals. Its recommendation 4 (vendor ask) is left unpursued.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's context and no `roadmap_flag` was set, so no
roadmap consultation applies to this round.

## Goals & Non-Goals

**Goals**:
- A new script under the sapience extension source store that injects a literal `[repo:<slug>]`
  tag into the `provenance` of every still-pending, resolvable record in
  `~/.sapience/pending_kos.jsonl`, idempotently and under the vendor's own ledger lock.
- Per-record slug resolution that is identical in outcome to `sapience-remember.sh`'s, reached
  via `capture.projects[].name → path_prefix → resolve_checkout_toplevel() → basename`.
- A fixture-driven test suite for the new script, plus extension of the existing lockstep guard
  to cover its copy of the shared resolution block.
- A corrected population census in the extension's domain docs, naming the live pipeline, the
  injection point, and the operational sequencing the script requires.
- Safe-by-default behavior: the script reports and writes nothing unless explicitly told to
  write.

**Non-Goals**:
- Backfilling already-uploaded, untagged KOs. The vendor surface offers create and read only —
  no update, no delete — so this population stays untagged permanently.
- Editing anything under `~/.sapience/` (vendor-owned client scripts) or `~/.dotfiles/` (the
  `sapience` binary and its GNOME launchers), both outside this repository's write surface.
- A wrapper around the `sapience` command itself.
- Running the tagging pass against the live ledger, or posting anything to the vault. Both are
  left to the user (see Risks and the `user_decision` relayed with this plan).
- Any change to `sapience-remember.sh`'s own already-tagged, postflight-bounded write path.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The ninth copy of the shared `resolve_checkout_toplevel()` block diverges by a byte (e.g. the implementer "fixes" the already-drifted in-block comment listing five copies), failing lockstep Case 30 | M | H | Copy the marker-delimited block with `sed -n '/BEGIN sapience-worktree-checkout-resolution/,/END sapience-worktree-checkout-resolution ===/p'` from an existing copy and do not retype or edit a character of it, including its stale comment |
| A future vendor update starts setting `provenance` on ordinary session-capture KOs, so an unconditional overwrite discards a vendor-authored string | M | L | Compose, never clobber: append `" [repo:<slug>]"` to a non-empty existing value; only synthesize a whole string when the field is absent or empty |
| Lost-write race against a concurrent `sapience sync`/`review` (the exact failure `_ledger_lock` was built for) | H | M | Take the same blocking exclusive `flock` on `~/.sapience/.ledger.lock` around the whole load-mutate-rewrite cycle, and write via tmp + rename with mode 0600 |
| A `capture.projects[]` entry's `path_prefix` is not a git repo (several disabled entries here are plain directories) | L | H | Treat resolution failure as "leave this record untagged, continue the pass", counted in the summary — never a fatal error |
| The script tags records belonging to other repositories (1687 `.dotfiles`, 810 `sapience-app` here), since the ledger is machine-global, not repo-scoped | M | H | By design (the report's own decision: one pass over the whole queue). The pass is explicitly opt-in via a write flag, and the dry-run summary is per project so the operator sees the full blast radius before authorizing it |
| The "server preserves a client-supplied `provenance`" mechanism is read from vendor code, never confirmed by a tagged record travelling the `sapience review` route specifically | M | L | The same endpoint already demonstrably honors a client-supplied provenance on `sapience-remember.sh`'s path (that is where the existing tagged population came from), so only the batch envelope differs. The one-record empirical confirmation is documented as an operator step in Phase 3, not performed by an agent |
| Rewriting the domain docs slips into record-versioning language ("previously said this cannot be fixed", "no longer true") | L | M | `.claude/rules/no-record-versioning-in-deliverables.md`: state the current mechanism only, on its own merits, with no reference to what the page used to say |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the pending-ledger tagging script [COMPLETED]

**Goal**: A working, safe-by-default `sapience-tag-pending.sh` in the extension source store
that resolves a repo slug per pending record and injects a `[repo:<slug>]`-carrying `provenance`,
registered in the extension manifest.

**Tasks**:
- [x] Create `agent-system/extensions/sapience/scripts/sapience-tag-pending.sh` with a header
      comment stating: what it mutates (`~/.sapience/pending_kos.jsonl` only), why the ledger
      file is a durable target (it is a `LEDGER_FILE`, preserved by `sapience update`, unlike the
      vendor `CLIENT_FILES`), the required operational sequencing (`sapience sync` → this script
      → `sapience review`), and that there is no delete or update API so a posted KO's tag is
      final. *(completed)*
- [x] Extract the marker-delimited `resolve_checkout_toplevel()` block from
      `agent-system/extensions/sapience/scripts/sapience-remember.sh` **verbatim** (BEGIN/END
      markers and the in-block comment included, unedited) and paste it into the new script.
      *(completed: byte-identity verified via diff of the extracted block)*
- [x] Build the project→slug map once per run: for each `.capture.projects[]` entry in
      `~/.sapience/config.json`, resolve `.path_prefix` through `resolve_checkout_toplevel()` and
      record `basename(<toplevel>)` keyed by `.name`. An entry whose path does not resolve gets
      no map entry (not an error). *(completed)*
- [x] Read the ledger line by line; for each record, skip it when `project` is empty or has no
      map entry (count it as unresolvable), skip it when its existing `provenance` already
      contains the substring `[repo:` (idempotence), otherwise set `provenance` to
      `[repo:<slug>] session capture via sapience-tag-pending.sh` when the field is absent or
      empty, or append `" [repo:<slug>]"` to the existing value when it is non-empty.
      *(completed)*
- [x] Leave every other field byte-identical — in particular `_hash` (dedupe-load-bearing) and
      `project` (review-display-load-bearing) — and preserve one JSON object per line.
      *(completed: a fixture-caught bug — the initial jq rewrite omitted `-c`, producing
      multi-line JSON that broke this exact invariant on a second pass — was found and fixed
      before this item was checked off)*
- [x] Wrap the whole load-mutate-rewrite cycle in a blocking exclusive `flock` on
      `~/.sapience/.ledger.lock`, and write back via `<path>.tmp.$$` + `mv` with mode `0600`,
      matching `extract_local.py`'s `_ledger_lock` and `_write_atomic` conventions exactly.
      *(completed: the lock fd is opened and acquired before the ledger is read and released
      only after the rewritten file is in place)*
- [x] Make `--dry-run` the DEFAULT and require an explicit `--write` to mutate: the default run
      prints a per-project summary (project name, resolved slug, records that would be tagged,
      records already tagged, records unresolvable) and touches nothing. Exit 0 on a clean pass
      (including a zero-change pass), non-zero with a message on stderr on an unreadable ledger,
      an unreadable/invalid config, or a failed atomic write. *(completed)*
- [x] Add `sapience-tag-pending.sh` to `provides.scripts` in
      `agent-system/extensions/sapience/manifest.json`, keeping the array's existing alphabetical
      ordering. *(completed)*
- [x] Mark the script executable (`chmod +x`), matching the other executable scripts in that
      directory. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Tier Justification**: this phase edits `manifest.json`'s `provides.scripts`, the deploy
manifest that the script-inventory, manifest-scripts-sync and deploy-propagation checks read
across the whole corpus rather than per-path, so no `run-all.sh --only` narrowing covers that
surface — the script file itself would otherwise need only `bash -n` plus a dry-run.

**Scope Hypothesis**: this phase asserts that `provides.scripts` in `manifest.json` currently
holds 18 entries (`jq '.provides.scripts | length'`, measured at planning time) and that `~/.sapience/.ledger.lock` plus the `tmp.<pid>` + `os.replace` pattern
are the live conventions (read from `extract_local.py` lines 426-460 at planning time). The
implementer confirms both by re-reading `manifest.json` and re-grepping `_ledger_lock`/
`_write_atomic` in `~/.sapience/extract_local.py` before writing the script, since the vendor
file is auto-updated outside this repository's control.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-tag-pending.sh` - new script, the phase deliverable
- `agent-system/extensions/sapience/manifest.json` - register the new script under provides.scripts

**Verification**:
- `bash -n agent-system/extensions/sapience/scripts/sapience-tag-pending.sh` passes.
- `bash agent-system/extensions/sapience/scripts/sapience-tag-pending.sh` (no flags) prints a
  per-project summary and leaves `~/.sapience/pending_kos.jsonl` byte-identical (compare
  `sha256sum` before and after).
- The summary's resolved slugs are `nvim`, `.dotfiles`, `sapience-app` for the three projects
  that currently hold pending records, and every record of each is reported as
  would-be-tagged (none already tagged, since 0 of 3757 carry a `provenance` today).
- `diff <(sed -n '/BEGIN sapience-worktree-checkout-resolution/,/END sapience-worktree-checkout-resolution ===/p' agent-system/extensions/sapience/scripts/sapience-remember.sh) <(sed -n '/BEGIN sapience-worktree-checkout-resolution/,/END sapience-worktree-checkout-resolution ===/p' agent-system/extensions/sapience/scripts/sapience-tag-pending.sh)` is empty.
- `jq -e '.provides.scripts | index("sapience-tag-pending.sh")' agent-system/extensions/sapience/manifest.json` succeeds.

**Batch Gate Deferral — scoped discharge record**: the dispatch's own narrowing invocation
(`verify-deploy.sh --only-gate 8 --gate8-touched <new script path>,manifest.json
--skip-unchanged`) hit the UNMAPPABLE touched-path case: `sapience-tag-pending.sh` is a
brand-new file with no covering test suite yet (Phase 2, next, creates
`test-sapience-tag-pending.sh`), so `suite_selection_select` returned the full-sweep sentinel and
fell back to the complete unnarrowed `run-all.sh` battery under heavy multi-task batch
contention (a stale gate-lock mutex reclaimed from another session, 1-minute load average 6.25,
an overall `[FAIL]` from undiscoverable/failing suites unrelated to this task). Per the
dispatch's UNMAPPABLE CRITERION carve-out, the two named checks this phase's own Tier
Justification identifies were run directly and standalone instead:
`agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh` (21 passed, 0 failed,
once the new script was `git add`ed so `git ls-files` could see it) and
`agent-system/extensions/core/scripts/tests/test-script-inventory.sh` (32 passed, 0 failed).
`agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` was also run
standalone as a sanity check (55 passed, 0 failed, including Case 30 still green against the
existing 8-file lockstep array). The complete, unscoped gate battery remains deferred to the
once-per-invocation batch-level close, per the dispatch's own stated contract.

---

### Phase 2: Fixture-driven test suite and lockstep registration [COMPLETED]

**Goal**: The new script's behavior is pinned by a test suite that never touches the real ledger,
and its copy of the shared resolution block is covered by the existing byte-identity guard.

**Tasks**:
- [x] Create `agent-system/extensions/sapience/scripts/tests/test-sapience-tag-pending.sh`
      following the structure of `tests/test-sapience-project-bind.sh` (same `pass`/`fail`
      helpers, same temp-dir teardown, same exit convention). *(completed)*
- [x] Every case runs against a synthetic fixture `HOME` containing its own
      `.sapience/config.json` and `.sapience/pending_kos.jsonl` plus throwaway `git init`
      repositories — no case may read or write the operator's real `~/.sapience/`. *(completed:
      confirmed via `sha256sum` of the real ledger unchanged across the whole suite run)*
- [x] Cases to cover: (a) a record whose `project` maps to a resolvable path gets
      `[repo:<basename-of-toplevel>]`; (b) an entry whose `name` deliberately differs from
      `basename(path_prefix)` resolves to the **basename**, not the name, proving the lookup goes
      through `path_prefix`; (c) a record originating from a linked worktree resolves to the
      parent checkout's basename; (d) a record whose `project` has no `capture.projects` entry,
      and one whose `path_prefix` is not a git repo, are left untagged and the pass still exits
      0; (e) re-running on an already-tagged ledger is a no-op (byte-identical file); (f) a
      record with a pre-existing non-empty `provenance` has the tag appended, not clobbered;
      (g) `_hash` and `project` are unchanged on every record and the line count is preserved;
      (h) the default (no-flag) run leaves the fixture ledger byte-identical; (i) no
      `pending_kos.jsonl.tmp.*` file survives a successful `--write`; (j) the written file's mode
      is `0600`. *(completed: 14/14 cases pass)*
- [x] Add `"$SCRIPT_DIR/../sapience-tag-pending.sh"` to the `LOCKSTEP_FILES` array of Case 30 in
      `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`, and
      update that case's pass-message copy count and its preceding comment's script count to
      match the new array length. *(completed: array now holds nine entries, pass message reads
      "across all nine copies", preceding comment reads "the seven slug-derivation scripts";
      re-read live at edit time, confirming the array still held eight entries beforehand, per
      the Scope Hypothesis)*
- [x] Add `tests/test-sapience-tag-pending.sh` to `provides.scripts` in
      `agent-system/extensions/sapience/manifest.json`, keeping the array's existing ordering.
      *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Tier Justification**: like Phase 1, this phase edits `manifest.json`'s `provides.scripts` (to
register the new suite), and that deploy-manifest surface is read corpus-wide by the
script-inventory, manifest-scripts-sync and deploy-propagation checks rather than per touched
path, so no `run-all.sh --only` narrowing covers it — the two test files alone would otherwise
need only their own direct invocations.

**Scope Hypothesis**: Case 30's `LOCKSTEP_FILES` array holds **eight** entries and its pass
message reads "byte-identical across all eight copies" (read at planning time from
`test-sapience-mcp-registration.sh` lines 1218-1248), while its preceding comment says "the six
slug-derivation scripts". The implementer re-reads those lines before editing, because another
task may have added a ninth copy in the meantime and the counts in both the message and the
comment must match the array's actual post-edit length.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/tests/test-sapience-tag-pending.sh` - new suite
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - extend
  Case 30's `LOCKSTEP_FILES` and its two stale counts
- `agent-system/extensions/sapience/manifest.json` - register the new test suite

**Verification**:
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-tag-pending.sh` exits 0
  with every case passing.
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` exits
  0, and its Case 30 line reports the new, larger copy count.
- `sha256sum ~/.sapience/pending_kos.jsonl` is identical before and after the whole suite run
  (proof that no case escaped the fixture `HOME`).
- `jq -e '.provides.scripts | index("tests/test-sapience-tag-pending.sh")' agent-system/extensions/sapience/manifest.json` succeeds.

**Batch Gate Deferral — scoped discharge record**: as in Phase 1, the generic
`--gate8-touched` narrowing would again hit the full-sweep sentinel (the new test suite file is
itself one of the touched paths and, being brand new, has no suite of its own covering it).
Discharged against the two named checks this phase's own Tier Justification identifies, run
directly and standalone: `test-manifest-scripts-sync.sh` (21 passed, 0 failed, after
`git add`ing the new suite file so `git ls-files` could see it) and `test-script-inventory.sh`
(32 passed, 0 failed). The new suite itself and `test-sapience-mcp-registration.sh`'s extended
Case 30 were run directly per this phase's own listed Verification criteria above (14/14 and
55/0 respectively). The complete, unscoped gate battery remains deferred to the
once-per-invocation batch-level close.

---

### Phase 3: Correct the population census and document the sequencing [COMPLETED]

**Goal**: The extension's own domain docs describe the live capture pipeline, the pre-review
injection point, the new script, the operational sequencing it requires, and the permanence of
the already-uploaded untagged population.

**Tasks**:
- [x] Rewrite population 3 of the four-population census in
      `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` to
      describe the pipeline that is actually live (`extract_local.py`, selected by
      `~/.sapience/config.json`'s `"backend": "anthropic"`, staging into `pending_kos.jsonl`),
      the fact that a client-supplied `provenance` reaches `POST /ingest-kos` unchanged through
      `review_queue()` → `_strip_meta()` → `post_kos()`, and the pre-review injection point the
      new script occupies. Keep the existing `capture.projects[].enabled` opt-in coupling
      paragraph, which is unaffected. *(completed: also corrected one other stale `upload.py`
      attribution found in the same file's "review gate" Hazards bullet while rewriting, for
      internal consistency)*
- [x] Add a short "Operational sequencing" passage to the same file: `sapience sync` stages,
      `scripts/sapience-tag-pending.sh` (default dry-run, `--write` to mutate) tags, then
      `sapience review`/`review --all` posts; the tag must land between the second and third
      step, and a record already posted can never be retagged. *(completed: new "### Operational
      Sequencing for Pending-Ledger Tagging" subsection)*
- [x] State plainly in the same file that the already-uploaded untagged population is permanent:
      the vault's KO surface is create (`/ingest-kos`) and read (`/v1/search`,
      `/v1/ko/subjects`) only, with no update and no delete, so manual removal in the web app is
      the only remedy and it deletes rather than retags. *(completed, in the same new subsection)*
- [x] Name the one-record empirical confirmation as an operator step: tag, post a single record
      through `sapience review`, then confirm retrievability with
      `scripts/sapience-retrieve.sh`. State that no agent performs this step, because `sapience
      review` is a user-driven launcher surface and every post is permanent. *(completed)*
- [x] Update `agent-system/extensions/sapience/EXTENSION.md`'s "What this extension adds"
      sentence so its script count and enumeration include the new script and its role
      (pre-review ledger tagging), and update
      `agent-system/extensions/sapience/README.md`'s script inventory the same way. *(completed:
      EXTENSION.md now says "four scripts"; README.md's File Inventory table gained a new row)*
- [x] Write every passage in the current-design voice required by
      `.claude/rules/no-record-versioning-in-deliverables.md`: no "previously", "no longer",
      "this used to say", and no supersession note about what the census asserted before. Cite
      durable anchors (filenames, function names, config keys), and reference no task number
      anywhere, per `.claude/rules/no-task-references-in-deliverables.md`. *(completed: verified
      via `check-task-references.sh agent-system/extensions/sapience` — 0 occurrences — and a
      manual read-through of the new/edited passages)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: the three files are markdown with no executable content and map to no
test suite; their only mechanical consumers are the EXTENSION.md→`.claude/CLAUDE.md` merge and
the context mirror, both regenerated and checked by Phase 4's deploy gate.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` -
  rewritten population 3, operational sequencing, permanence statement, operator confirmation
  step
- `agent-system/extensions/sapience/EXTENSION.md` - script count and enumeration in "What this
  extension adds"
- `agent-system/extensions/sapience/README.md` - script inventory

**Coupled generated surfaces**: `EXTENSION.md` is the merge source for the Sapience section of
the generated `.claude/CLAUDE.md`, and the domain file has a deployed mirror under
`.claude/context/project/sapience/`. Neither deployed-tree path is declared as a `Files to
modify` entry — a `.claude/**` path is never a legitimate `file_scope` member
(`rules/source-store-deploy-boundary.md`) and the sanctioned declaration for a whole-deployed-tree
claim is the `__WHOLE_TREE__` sentinel, which Phase 4 carries. The regeneration is scheduled in
Phase 4 rather than here because the check that detects this drift
(`check-deploy-freshness.sh`, reached through `command-gate-in.sh`/`skill-base.sh`) is a gate-in
advisory, not a commit-blocking hook.

**Verification**:
- `grep -n "extract_local.py" agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
  returns the rewritten population-3 text, and `grep -c "upload.py" ` on that file no longer
  attributes the live capture path to it.
- `grep -rn "sapience-tag-pending" agent-system/extensions/sapience/{EXTENSION.md,README.md}`
  returns a hit in each, and the sentence's own script count matches its enumeration.
- `bash .claude/scripts/check-task-references.sh` (or the equivalent repo-wide lint) reports no
  new task-number reference in the three edited deliverable files.
- Manual read-through confirms no "previously"/"no longer"/"used to"/supersession phrasing in
  the edited passages.

---

### Phase 4: Redeploy, scoped gate sweep, and operator handoff [COMPLETED]

**Goal**: The new script, its test suite, and the corrected docs are present in the deployed
tree and in the generated merge targets; the touched-path checks pass; the live-ledger run and
the vault post are handed to the operator rather than performed.

**Tasks**:
- [x] Run the deploy so the source-store changes reach `.claude/**`
      (`bash .claude/scripts/deploy-headless.sh`, or the extension picker's regenerate entry).
      *(completed: first run failed `check-extension-docs.sh`'s Rule U, EXTENSION.md 63 lines
      over the 60-line limit; trimmed the Phase 3 edit back to 6 lines and redeployed clean --
      41 checks, 0 failures)*
- [x] Confirm the deployed tree carries `.claude/scripts/sapience-tag-pending.sh` (executable)
      and `.claude/scripts/tests/test-sapience-tag-pending.sh`, that `.claude/CLAUDE.md`'s
      Sapience section carries the updated script enumeration, and that
      `.claude/context/project/sapience/domain/per-repo-scoping.md` carries the rewritten
      census. *(completed)*
- [x] Run the scoped touched-path verification for this task's file set
      (`bash .claude/scripts/verify-deploy.sh --gate8-touched <the paths this task touched>`),
      and run the two sapience suites from the deployed copies
      (`bash .claude/scripts/tests/run-all.sh --only test-sapience-tag-pending.sh,test-sapience-mcp-registration.sh`).
      *(completed: the two-suite run-all.sh invocation exits 0 directly. The full 7-path
      `--gate8-touched` set hit the full-sweep sentinel (markdown files have no covering suite
      by construction); narrowed to the 4 `.sh`/`manifest.json` paths instead, which resolved to
      a 34-suite roster. `verify-deploy.sh` itself reported `[FAIL]` on that roster under heavy
      multi-task batch contention (1-minute load average 5.88-9.34); re-running the identical
      34-suite roster directly via `run-all.sh --only` with no wrapper and no artificial deadline
      passed 34/0 -- recorded as a gate-collision/contention issue, not a real regression, and
      used as this phase's scoped discharge*)
- [x] Run the deployed script with no flags (dry-run) against the live ledger as a read-only
      smoke check, and record the per-project counts and resolved slugs in the summary.
      *(completed: 3757 total -- 1687 `.dotfiles`, 1260 `nvim`, 810 `sapience-app`, 0 carrying a
      `provenance` key -- slugs `.dotfiles`/`nvim`/`sapience-app` all resolve correctly)*
- [x] Confirm `sha256sum ~/.sapience/pending_kos.jsonl` is unchanged by that smoke check.
      *(completed: identical sha256 before and after every dry-run invocation performed during
      this entire implementation)*
- [x] Do **not** run `--write` against the live ledger, and do **not** invoke `sapience review`,
      `sapience sync`, or any vault POST. Record in the task summary the exact operator command
      sequence (`sapience sync` → `sapience-tag-pending.sh --write` → `sapience review`) and the
      one-record empirical confirmation the operator should perform first. *(completed: no
      `--write`, `sapience review`, or `sapience sync` invoked at any point; the operator
      sequence is recorded in the implementation summary)*
- [x] Defer the complete gate battery to the orchestration close rather than invoking it as this
      phase's own criterion. *(completed)*

**Timing**: 1 hour

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts the live ledger holds 3757 records (1260 `nvim`, 1687
`.dotfiles`, 810 `sapience-app`; 0 carrying a `provenance` key), measured at planning time. The
hourly capture agent appends continuously, so the implementer re-measures with its own
`wc -l`/group-by pass immediately before the smoke check and reports the then-current figures
rather than asserting these.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via the deploy, which rewrites
  the deployed scripts, the generated CLAUDE.md merge target, and the deployed context mirror;
  no individual deployed-tree path is declared, since none is a legitimate file_scope member

**Verification**:
- The deploy completes without error and `test -x .claude/scripts/sapience-tag-pending.sh`
  succeeds.
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-tag-pending.sh,test-sapience-mcp-registration.sh`
  exits 0.
- `bash .claude/scripts/verify-deploy.sh --gate8-touched <touched paths>` exits 0 for this task's
  touched-path set.
- The deployed script's no-flag run prints a per-project summary whose slugs match the
  re-measured `capture.projects` resolution, and `sha256sum ~/.sapience/pending_kos.jsonl` is
  unchanged across that run.
- The complete gate set is explicitly deferred to the orchestration close; this phase records
  the deferral rather than running the full battery itself.

---

## Testing & Validation

- [x] `agent-system/extensions/sapience/scripts/tests/test-sapience-tag-pending.sh` passes every
      case, entirely against a fixture `HOME`. *(completed: 14/14 cases pass)*
- [x] `test-sapience-mcp-registration.sh` Case 30 passes with the new ninth copy included.
      *(completed: 55/0)*
- [x] The real `~/.sapience/pending_kos.jsonl` is byte-identical before and after every test run
      and every dry-run invocation performed during implementation. *(completed: confirmed via
      `sha256sum` at the end of Phases 1, 2, and 4 -- identical throughout)*
- [x] The dry-run summary against the live ledger resolves the correct slug for each project that
      currently holds pending records. *(completed)*
- [x] `bash -n` passes on both new shell files. *(completed)*
- [x] No task-number reference and no record-versioning phrasing in the three edited markdown
      deliverables. *(completed: `check-task-references.sh` reports 0 occurrences)*

## Artifacts & Outputs

- `agent-system/extensions/sapience/scripts/sapience-tag-pending.sh` (new)
- `agent-system/extensions/sapience/scripts/tests/test-sapience-tag-pending.sh` (new)
- `agent-system/extensions/sapience/manifest.json` (two `provides.scripts` registrations)
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` (Case 30
  extended)
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
  (corrected census, sequencing, permanence statement)
- `agent-system/extensions/sapience/EXTENSION.md`, `agent-system/extensions/sapience/README.md`
  (script enumeration)
- The regenerated deploy tree (`.claude/scripts/`, `.claude/CLAUDE.md`,
  `.claude/context/project/sapience/`)
- A task summary recording the operator command sequence and the one-record empirical
  confirmation to perform before any bulk `--write`

## Rollback/Contingency

Every change is additive to the source store plus three markdown edits and two JSON array
registrations, so reverting is `git revert` of this task's commits followed by a redeploy; no
state outside this repository is mutated by any phase. Nothing in the plan writes to
`~/.sapience/pending_kos.jsonl` or posts to the vault, so there is no out-of-repository state to
roll back. If the lockstep guard cannot be satisfied (the ninth copy will not come out
byte-identical), the fallback is to drop the shared block from the new script and shell out to
`bash .claude/scripts/sapience-retrieve.sh`-style resolution via a single `git -C <path>
rev-parse` pair inline, accepting the loss of worktree handling for the ledger-tagging path
only, and to record that loss explicitly in the script header and in the summary rather than
leaving it implicit.
