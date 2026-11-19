# Research Report: Task #649

**Task**: 649 - Add the /sapience command: draft assembly and the approval-gated surface picker
**Started**: 2026-11-19T12:40:00Z
**Completed**: 2026-11-19T13:30:00Z
**Effort**: ~4-6 hours (one command.md, one SKILL.md, manifest/README/EXTENSION.md/index-entries.json edits, no new scripts)
**Dependencies**: 647 (sapience_project_binding_and_vault_read, completed), 648 (sapience_publish_write_surfaces, completed)
**Sources/Inputs**: Codebase (agent-system/extensions/sapience/**, agent-system/extensions/literature/**, agent-system/extensions/core/skills/skill-roadmap, skill-meta, agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md, agent-system/extensions/core/context/standards/interactive-selection.md, agent-system/extensions/core/scripts/check-extension-docs.sh), external reference (/home/benjamin/Projects/Sapience/sapience-app/brain_server.py, read-only, no vault network calls made)
**Artifacts**: specs/649_sapience_command_picker_and_draft/reports/01_sapience-command-picker-draft.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both dependency tasks (647, 648) are complete and already deployed: `scripts/lib/sapience-api-lib.sh`,
  `scripts/sapience-vault-read.sh` (the full draft-assembly read envelope, schema
  `sapience-vault-read/1`), `scripts/sapience-project-bind.sh`, and `scripts/sapience-publish.sh`
  (`doc-comment`/`doc-version`/`dm`/`ko` subcommands, each dry-run-by-default) all exist in the source
  store and pass their own test suites. **This task adds no new script** — `commands/sapience.md` and
  `skills/skill-sapience/SKILL.md` are pure consumers of the four scripts above.
- Task 581 (the shared AskUserQuestion option-rendering helper) is confirmed `not_started` — keep the
  picker's option-construction code in exactly one place inside `skill-sapience/SKILL.md` per the
  dispatch's coordination note, with no dependency edge added.
- The four candidate write surfaces named in the dispatch (doc comment, decision-log row, repo-tagged
  KOs, DM) map 1:1 onto AskUserQuestion's **measured 4-option-per-question ceiling** (task 581's own
  description cites this limit) — the picker needs no batching/narrowing strategy at all, which removes
  one potential design hazard before it starts.
- **`EXTENSION.md` is not the only doc that must change.** `check-extension-docs.sh`'s
  `check_readme_vs_manifest()` fails the build if a command named in `manifest.json`'s
  `provides.commands` is not textually mentioned as `/<name>` in the extension's own `README.md`.
  Sapience's current `README.md` states outright "This extension provides no task type, no routing
  agents, and no slash command" — that sentence and the file's "No task type, no routing, no slash
  command" line in `EXTENSION.md` both become false the moment `commands/sapience.md` exists, and both
  files must be updated or the deploy gate fails. The dispatch's FILE SCOPE list named `EXTENSION.md`
  but not `README.md`; this is a gap in the dispatch, not a license to skip README.md.
- `GET /v1/docs`'s per-doc `activity` field (`{kind, by, at, text, n}` — confirmed against
  `brain_server.py`'s `docs_activity()`) gives a concrete, code-grounded answer to "which doc is most
  relevant to reply to": the doc whose `activity.by` is the collaborator (not "me") and whose
  `activity.at` is most recent is the doc that most recently had the collaborator's own comment, answer,
  or edit land on it — exactly the "respond to a collaborator's latest rather than talk past it"
  requirement the dispatch states as the point of reading the comment/notification surfaces.
- No Agent-tool dispatch of a named `subagent_type` is architecturally required anywhere in this
  command. Unlike `skill-roadmap`/`skill-meta` (which collect user choices in the skill, THEN dispatch a
  judgment-bearing subagent for the heavy work), `/sapience`'s entire job — reading the vault-read
  envelope, drafting text, building the picker, and calling the publisher scripts — fits comfortably
  inside the skill's own direct execution, matching `skill-literature`'s shape (no agent dispatch at
  all) rather than `skill-roadmap`'s (pre-delegation picker, then dispatch). This sidesteps the
  Tool-Withholding hazard entirely rather than merely working around it.

## Context & Scope

Researched: the exact script interfaces, payload shapes, and envelope contract the two dependency tasks
already built; the extension's current manifest/README/EXTENSION.md/index-entries.json state and what
must change; the precedent for collecting an AskUserQuestion picker inside a skill's own execution
before any subagent dispatch (`skill-roadmap`, `skill-meta`); the extension layout convention
(`agent-system/extensions/literature/**` as the confirmed reference); the AskUserQuestion 4-option
ceiling and whether the four candidate surfaces fit under it; and live Sapience server source
(`brain_server.py`) for the exact per-doc/comment/notification field shapes a draft-assembly consumer
needs to read. No network call was made to the vault during this research — all server-side
confirmation came from reading `brain_server.py` directly, consistent with the prior two tasks' own
practice of reading the server source rather than probing live for routes that do not mutate state.

Out of scope (per the dispatch's own Non-Goals/dependency boundaries): building any new script (the
four scripts already exist); migrating any existing script onto the `project_cid`/`REPO_LINK_FOR` dark
path; extracting the shared AskUserQuestion renderer (task 581, explicitly not blocked on).

## Findings

### Codebase Patterns

**Extension layout convention** (confirmed against `agent-system/extensions/literature/`, which already
has `commands/`, `skills/skill-<name>/SKILL.md`, `scripts/`, `scripts/lib/`, `scripts/tests/`): a command
file is `commands/<name>.md` with frontmatter `description`, `allowed-tools: Skill`, `argument-hint`, and
a body stating `**Delegates To**: skill-<name> (direct execution)`; `provides.commands` in
`manifest.json` lists `<name>.md`; `provides.skills` lists the skill's directory name
(`skill-<name>`), not a path. `sapience/manifest.json` currently has both arrays empty — confirming the
dispatch's claim that no command surface exists yet.

**The four scripts this command consumes, with their exact CLI and payload shapes** (all already built,
tested, and deployed by tasks 647/648):

- `scripts/lib/sapience-api-lib.sh` — `sapience_api_init` (resolves `$sapience_host`/`$sapience_token`
  into the caller's shell; never echoes the token), `sapience_post <path> <json-body>` (sets
  `sapience_api_post_http_status`), `sapience_get <path> [query-string]` (one bounded 503-cold-start
  retry). `SAPIENCE_DRY_RUN=1` makes either helper print the redacted request and return 0 with no
  network call — this is the literal-payload mechanism the picker's "show literal payload" requirement
  should reuse directly rather than re-deriving a preview format.
- `scripts/sapience-vault-read.sh [--since <ref>] [--update-cursor] [--project <cid>]` — emits the pinned
  `sapience-vault-read/1` envelope on stdout: `repo.{toplevel,name,binding}`,
  `local.{git,state,events,errors,sessions}`, `vault.{projects,docs,doc_bodies,doc_comments,
  project_notes,suggestions,notifications}`, top-level `errors[]`. Per-source failure isolation (a
  single failing top-level source leaves its key `null` and records into `errors[]`; exit 2 only if all
  five top-level vault sources fail). `doc_bodies`/`doc_comments` are per-doc follow-ons bounded to
  `MAX_DOC_FETCH=10` **docs flagged `unread: true`** — this is the draft-assembly command's only source
  of comment/body content without issuing its own additional GETs, so the command's "respond to a
  collaborator's latest" requirement is bounded by this same 10-doc cap (acceptable: there are only 4
  Oliver+Ben docs today per the dispatch's live reference values).
- `scripts/sapience-project-bind.sh --name "<name>" --confirm [--to <id>]` — NOT a surface this command
  calls autonomously (HARD CONSTRAINT 5: project creation is an outward-facing mutation the command must
  never trigger unattended). Relevant to this command only as the reader of `.sapience/project.json`
  (already read by `sapience-vault-read.sh`'s `repo.binding`), and as the thing a user would run
  separately, once, before `/sapience` has a bound project at all.
- `scripts/sapience-publish.sh <subcommand> ... [--confirm]` — four subcommands, every one dry-run by
  default, sharing one `--confirm`/`--dry-run` flag-parsing trio:
  - `doc-comment <slug> --body <text> [--quote <text>] [--reply-to <id>] [--resolve] [--confirm]` → POST
    `/v1/docs/<slug>/comments`; dry-run prints the exact `{body, quote?, reply_to?, resolve?}` payload.
  - `doc-version <slug> --body-file <path> [--title <text>] [--confirm]` → always performs the `GET
    /v1/docs/<slug>` fetch (even under dry-run) to resolve the real `base_rev` before printing the
    payload, then POSTs `{body, base_rev, title?}`. Four distinct outcomes: `409 head_moved` (refused,
    nothing written), `202` (proposed, awaiting owner — `can_edit:false` only), `404 share_gone`
    (refused), `2xx` (saved).
  - `dm --to <person-id> --body <text> [--confirm]` → two sequential writes (`POST /v1/people/dm` then
    `POST /v1/docs/<slug>/comments` on the resolved conversation slug); dry-run prints both literal
    payloads in sequence, the second with a `<slug>` placeholder since the DM call hasn't resolved it yet.
  - `ko --note <text> [--note <text> ...] [--project <cid>] [--confirm]` → resolves the project **key**
    (not cid) at runtime via `GET /v1/people/projects`, builds one KO per `--note` with
    `subject: "finding"`, `predicate: "finding is"`, `ko_type: "insight"`, `confidence: 0.8`,
    `explicit: true`, `project: "<resolved key>"`, POSTs all of them in one `/ingest-kos` call. This is
    the single call the "repo-tagged KOs" checkbox option should issue — one call per confirmed run,
    carrying every checked-and-confirmed note, never one call per note.

**AskUserQuestion-picker-before-dispatch precedent**: `skill-roadmap/SKILL.md` Stage 1 and
`skill-meta/SKILL.md` Section 2 both state, nearly verbatim, the exact rationale the dispatch gives:
`AskUserQuestion` is measured categorically withheld from every `Agent`-tool dispatch of a named
`subagent_type`, independent of frontmatter (`agent-frontmatter-standard.md`'s "Tool Withholding from
Dispatched Subagents" section, confirmed present with a 5-dispatch/4-configuration measurement table).
Both existing skills resolve this by collecting every user choice in the skill's OWN execution before
any `Agent`-tool call. **For `/sapience`, the stronger finding is that no `Agent`-tool dispatch is
needed at all** — `skill-literature/SKILL.md` is the closer precedent: a direct-execution skill
(`allowed-tools: Bash, Read, Write, Edit, AskUserQuestion`) that does its own synthesis, its own
AskUserQuestion prompts, and its own writes, with zero subagent dispatch. `/sapience`'s draft-assembly
step (reading the vault-read envelope and composing candidate text) and its write step (calling
`sapience-publish.sh`) are both well within a direct-execution skill's own reach; there is no
heavy, multi-turn, judgment-bearing delegation analogous to `roadmap-agent`'s batch-membership
reasoning or `meta-builder-agent`'s system design that would justify a subagent here.

**The 4-option ceiling fits exactly.** Task 581's own description states "AskUserQuestion accepts a
maximum of 4 options per question." The dispatch's four pre-checked-by-default candidate surfaces are:
(a) doc comment, (b) decision-log row, (c) repo-tagged KOs, (d) DM (present only when `--message` was
passed). When `--message` is absent, that is 3 options; when present, 4. Neither case requires the
batching/narrowing machinery task 581's predecessor record is building — this command's picker is
simple multi-select (`multiSelect: true`), one `AskUserQuestion` call, no tiering.

**"Decision-shaped" has no existing codebase precedent.** A repo-wide grep for `decision-shaped` /
`decision_shaped` outside this task's own scope found no classifier anywhere in
`agent-system/extensions/**`. This heuristic (used to decide whether the decision-log-row option is
pre-checked) is novel to this command and must be defined by the plan, not inherited from elsewhere.

**README.md / EXTENSION.md both currently assert no command exists.** `README.md`'s opening paragraph:
"This extension provides no task type, no routing agents, and no slash command." Its
"No task type, no routing, no slash command" closing section states the same, attributing it to GNOME
desktop launchers already covering review/sync/coverage/pending/stats. `EXTENSION.md`'s matching
sentence is identical. Both must be edited — not just `EXTENSION.md` as the dispatch's FILE SCOPE names —
or `check-extension-docs.sh`'s `check_readme_vs_manifest()` fails the gate (confirmed by reading its
source: it `jq`-extracts `provides.commands[]`, strips `.md`, and `grep -q "/$cmd_name"` against
`README.md`; a miss is a hard `fail`, not a warning).

**`check_referenced_scripts_declared`** scans `commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`,
`README.md`, and `EXTENSION.md` for any `*.sh`/`*.sql` token and requires it be in
`provides.scripts` (or `external_scripts`). Since this task adds no new script, the only scripts
`commands/sapience.md`/`skills/skill-sapience/SKILL.md` will mention
(`sapience-vault-read.sh`, `sapience-publish.sh`, `sapience-project-bind.sh`) are already declared in
`manifest.json` from tasks 647/648 — no manifest `provides.scripts` change is needed for this reason,
only the `provides.commands`/`provides.skills` additions the dispatch's item 6 already names.

**`GET /v1/docs`'s per-doc `activity` field answers "most relevant doc to reply to" concretely**
(confirmed against `brain_server.py`'s `docs_activity()`, lines ~25987-26020, and `_doc_head_fields()`,
lines ~25582-25588): each doc in the list carries `unread` (bool, read-mark vs. current hash),
`updated` (epoch), and `activity: {kind, by, at, text, n?}` — the newest of {head save, read mark,
newest comment, newest answer} on that doc, with `by` naming whoever did it and `text` a ≤120-char
excerpt. A draft-assembly pass that wants to "respond to the collaborator's latest rather than talk
past it" has a direct, mechanical target: among the bound project's docs, the one with the most recent
`activity.at` where `activity.by` is the collaborator (not "me") is the doc the collaborator most
recently touched — comment, answer, or edit — and is the natural default for the "most relevant doc"
comment-reply target, rather than a vaguer content-similarity heuristic.

**Comment response shape** (confirmed in `sapience-publish.sh`'s own header comment, matching the
server's verified 201 shape): `GET /v1/docs/<slug>/comments` and the write response both carry
`{slug, n, hash, author, at}` per comment — `author` and `at` are exactly what's needed to detect "the
collaborator's latest comment is still unanswered" (no reply from "me" with a later `n`/`at` on the
same thread).

**Live reference data from the dispatch, cross-checked**: the four Oliver+Ben docs
(`oliver-ben-decisions`, `oliver-ben-agenda`, `oliver-ben-rules`, `oliver-ben-updates`) all currently
have zero comments — so on a fresh run today, the "most relevant doc" heuristic above has no
`activity.by == collaborator` doc to prefer yet, and the command's design must specify a sane fallback
(e.g., most recently `updated` doc, or `oliver-ben-agenda` as the standing discussion doc) rather than
assume the collaborator-activity signal will always be present.

### External Resources

No external (non-codebase, non-Sapience-server-source) research was needed; this task's entire surface
is internal convention (extension layout, manifest/README parity, AskUserQuestion mechanics already
documented in this repository) plus the already-built sibling scripts' own interfaces.

## Recommendations

1. **No new script.** `commands/sapience.md` + `skills/skill-sapience/SKILL.md` should call the four
   existing scripts directly via Bash; building a fifth "assemble the picker payloads" script would
   duplicate logic the skill's own execution (an LLM, same as `skill-literature`) is better placed to do
   (drafting comment/decision-row/DM/KO text is a synthesis task, not a mechanical transform).
2. **No Agent-tool dispatch.** Follow `skill-literature`'s shape (fully direct execution:
   `allowed-tools: Bash, Read, Write, Edit, AskUserQuestion` — no `Agent` in the allowlist at all),
   not `skill-roadmap`'s pre-delegation-then-dispatch shape. This is a stronger, simpler resolution of
   the dispatch's "picker must run before any agent dispatch" constraint: eliminate the dispatch rather
   than work around its tool-withholding.
3. **Build the picker's four options from ONE option-construction site** inside
   `skills/skill-sapience/SKILL.md` (a single jq/bash block or helper function the AskUserQuestion call
   reads from), per the dispatch's coordination note — so task 581, when it lands, absorbs this fifth
   site without a scattered-call-site hunt.
4. **Reuse `SAPIENCE_DRY_RUN=1`'s existing literal-payload print exactly** as the picker's
   "show the literal payload" mechanism: call each of the four `sapience-publish.sh` subcommands once
   in dry-run mode to generate the preview text shown as each option's description, then re-invoke only
   the checked-and-confirmed ones with `--confirm` after the single AskUserQuestion resolves. This
   guarantees the preview and the real write are byte-identical in construction, matching the discipline
   `_post_comment`'s own header comment already states ("never a second, divergent preview string").
5. **Default "most relevant doc" to the doc with the most recent `activity.at` where
   `activity.by` is the collaborator**, falling back to the most recently `updated` doc among the bound
   project's docs when no doc has collaborator activity yet (today's live state: all four Oliver+Ben
   docs have zero comments, so the fallback path is the one that will actually fire on day one).
6. **Define "decision-shaped" explicitly in the plan** — no existing classifier to inherit. A simple,
   defensible starting point: the draft text contains an explicit decision marker (a "decided"/"we
   will"/"going with" phrase) or the git log since the last cursor contains a commit whose message
   matches this repo's own `task {N}: {action}` convention with action `create implementation plan` or
   `complete implementation` — but this is a design choice for the plan to make and justify, not a
   fact this research can settle.
7. **Update `README.md` alongside `EXTENSION.md`** — both currently assert no slash command exists;
   both must drop that claim and `README.md` specifically must contain the literal substring
   `/sapience` or `check-extension-docs.sh`'s gate fails the deploy.
8. **The `ko` picker option issues exactly one `sapience-publish.sh ko` call** carrying every
   checked-and-confirmed note via repeated `--note`, bounded to the existing 3-8-note range (HARD
   CONSTRAINT 2) — never one call per note, and never a second, independently-sized bound.
9. **The collaborator picker (`--message [text]` with no name) is a second, separate AskUserQuestion**,
   built from `GET /v1/people`'s `people: [{id, name, ...}]` roster (the same endpoint
   `sapience-project-bind.sh` already uses for its own single-connection auto-resolve) — this picker
   runs BEFORE the final approval picker, not merged into it, since it selects WHO to draft a DM to,
   not WHETHER to send one.

## Decisions

- No new script is being built by this task; the plan should scope `Files to Modify/Create` to exactly
  the five paths the dispatch's FILE SCOPE lists, **plus `README.md`** (see Finding above — this is an
  addition to the dispatch's own list, not a deviation from it, since the dispatch's FILE SCOPE
  omission appears to be an oversight against its own cited enforcement mechanism).
- The command performs zero Agent-tool dispatches; `skill-sapience/SKILL.md`'s `allowed-tools` should
  therefore NOT include `Agent`, matching `skill-literature` rather than `skill-roadmap`/`skill-meta`.
- The picker is a single `AskUserQuestion` call with `multiSelect: true` and 3-4 options (no tiering, no
  task-581 batching needed) — confirmed against the dispatch's own 4-surface enumeration and task 581's
  documented 4-option ceiling.

## Risks & Mitigations

- **Risk**: a plan that treats `EXTENSION.md` as the only doc update (per the dispatch's literal FILE
  SCOPE) will fail `check-extension-docs.sh`'s README/manifest parity check at deploy time.
  **Mitigation**: add `README.md` to the plan's file scope explicitly (see Decisions above); verify with
  `grep -q '/sapience' README.md` before closing the implementation.
- **Risk**: the "most relevant doc" and "decision-shaped" heuristics are both novel judgment calls with
  no existing precedent to anchor against, so an implementer could over- or under-engineer them.
  **Mitigation**: the plan should state each heuristic as an explicit, falsifiable rule (not "use
  judgment") so a reviewer can check it mechanically — see Recommendations 5 and 6 above for starting
  points grounded in verified server fields.
- **Risk**: calling each publisher subcommand in dry-run mode to build the picker's preview text means
  up to 2 extra network GETs per run (`doc-version`'s dry-run still fetches `base_rev` via a real GET;
  `ko`'s key-resolution GET `/v1/people/projects` is not needed for comment/DM dry-run previews but IS
  needed if the KO option's preview wants to show the resolved project key rather than the binding's
  raw cid). **Mitigation**: this is already the existing, tested behavior of the dependency scripts
  (`doc-version`'s header comment states this explicitly) — not a new risk this task introduces, but
  worth stating in the plan so a reviewer does not mistake it for an avoidable inefficiency.
- **Risk**: THERE IS NO DELETE API — every KO write and every doc-version save is permanent once
  confirmed, and the picker is the only gate. **Mitigation**: already addressed by HARD CONSTRAINT 3's
  design (the picker shows literal payloads, not summaries) — no new mitigation needed from this
  research pass; flagged here only so the plan does not relax that requirement under schedule pressure.

## Context Extension Recommendations

- **Topic**: The `/sapience` command's draft-assembly and picker mechanics (which doc is "most
  relevant," how "decision-shaped" is detected, the single-AskUserQuestion-call design, and the
  dry-run-preview-equals-confirmed-payload discipline).
- **Gap**: `agent-system/extensions/sapience/context/project/sapience/domain/` currently has six domain
  notes (vault-model, review-gate-boundary, per-repo-scoping, injection-site-scoping,
  transcript-filter-ceiling, subagent-orientation) but none document the command surface itself — once
  built, a future maintainer has no single place to read "how does /sapience decide what to draft and
  what to pre-check."
- **Recommendation**: the implementing task should add
  `context/project/sapience/domain/command-draft-and-picker.md` (or fold the same content into a new
  section of `README.md`'s File Inventory table) documenting the four candidate surfaces, the
  pre-check defaults, the "most relevant doc"/"decision-shaped" heuristics as implemented, and the
  single-option-construction-site location for task 581's eventual absorption — then add the
  corresponding `index-entries.json` entry (the dispatch's item already names `index-entries.json` as
  in scope for exactly this reason).

## Appendix

### Search queries / inspection used

- `jq` queries against `specs/state.json` for tasks 581, 647, 648, 649 (status, dependencies,
  description, audit_verdict)
- Full reads: `agent-system/extensions/sapience/{manifest.json,EXTENSION.md,README.md,
  index-entries.json,settings-fragment.json}`, all four scripts under
  `agent-system/extensions/sapience/scripts/{lib/sapience-api-lib.sh,sapience-vault-read.sh,
  sapience-project-bind.sh,sapience-publish.sh}`
- `specs/647.../summaries/01_...-summary.md`, `specs/648.../summaries/01_...-summary.md` (full reads)
- `agent-system/extensions/literature/{manifest.json,commands/literature.md,
  skills/skill-literature/SKILL.md}` for the layout/convention precedent
- `agent-system/extensions/core/skills/skill-roadmap/SKILL.md`,
  `agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md` ("Tool
  Withholding from Dispatched Subagents" section) for the picker-before-dispatch precedent
- `agent-system/extensions/core/context/standards/interactive-selection.md` for AskUserQuestion
  schema/threshold conventions
- `agent-system/extensions/core/scripts/check-extension-docs.sh` (`check_readme_vs_manifest`,
  `check_referenced_scripts_declared`) for the README/manifest parity gate
- `grep -rln "decision-shaped"` across `agent-system/extensions/` (no hits outside an unrelated
  books-extension false-positive-free miss)
- `/home/benjamin/Projects/Sapience/sapience-app/brain_server.py`: `docs_list`, `_doc_head_fields`,
  `docs_activity`, `doc_rev` (read-only source inspection; no live vault calls made)

### References

- `specs/649_sapience_command_picker_and_draft/.dispatch/10.md` (this dispatch)
- `specs/647_sapience_project_binding_and_vault_read/summaries/01_project-binding-vault-read-foundation-summary.md`
- `specs/648_sapience_publish_write_surfaces/summaries/01_sapience-publish-write-surfaces-summary.md`
- `agent-system/extensions/sapience/scripts/lib/sapience-api-lib.sh`
- `agent-system/extensions/sapience/scripts/sapience-vault-read.sh`
- `agent-system/extensions/sapience/scripts/sapience-project-bind.sh`
- `agent-system/extensions/sapience/scripts/sapience-publish.sh`
- `.claude/rules/sapience-write-path.md`
