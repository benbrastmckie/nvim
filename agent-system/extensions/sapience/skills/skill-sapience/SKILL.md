---
name: skill-sapience
description: Assemble a /sapience draft update from local repo state and read-only vault state, then gate every outward write behind one approval picker. Invoke for /sapience command.
allowed-tools: Bash, Read, Write, AskUserQuestion
---

# Skill: skill-sapience (Direct Execution)

**No `Agent` tool anywhere in this skill, by design (Decision D1 in the governing plan).**
`AskUserQuestion` is categorically withheld from every `Agent`-tool dispatch of a named
`subagent_type`, independent of frontmatter. This skill never dispatches at all — every stage
below, including the approval picker, runs in this session's own execution. This is a stronger
resolution than collecting choices before a dispatch: with no dispatch anywhere, the withholding
hazard cannot bite.

**Write-path contract**: every outward write this skill can issue goes through
`.claude/scripts/sapience-publish.sh`, doing a direct authenticated POST. No MCP write tool is
named anywhere in this file as a path a write should take. A Bash script call is not an MCP tool
invocation, so this needs no new grant beyond the 7-tool read-only set already in
`settings-fragment.json`.

See `context/project/sapience/domain/command-draft-and-picker.md` for the full design record
this skill implements against (the four candidate write surfaces, the pre-check defaults, the
most-relevant-doc and decision-shaped rules, the literal-payload discipline, the body-fetch
fallback, and the option-construction marker). This file applies those rules; it does not
re-derive or re-justify them.

## Mode Contract

`commands/sapience.md` parses `/sapience`'s arguments into exactly one of four shapes and passes
the result through as this skill's args:

| Shape | args | What it changes |
|-------|------|------------------|
| No arguments | `mode=default` | Prepare an update for the bound project; no collaborator chosen |
| Free text | `mode=default text={text}` | Same as above, with the text folded into the draft |
| `--message <Name> [text]` | `mode=message name={Name} text={text}` | Also DM the named collaborator once resolved |
| `--message [text]` | `mode=message_picker text={text}` | Present a collaborator picker (Stage 6) before the approval picker |

Every shape ends at the same single approval picker (Stage 9). No code path writes anything
without reaching it.

## Stage 1: Resolve Repo and the Binding Gate

```bash
repo_toplevel="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "skill-sapience: not inside a git repository -- cannot resolve a Sapience binding"
  exit 1
}
link_file="${repo_toplevel}/.sapience/project.json"
```

If `$link_file` exists and is valid JSON, this repository is already bound: there is no Project
binding candidate surface this run (nothing to pick), and Stage 2 proceeds as normal.

If `$link_file` does not exist or is not valid JSON, this is not a hard stop: run the read-only
pick and capture its listing:

```bash
pick_listing="$(bash .claude/scripts/sapience-project-bind.sh)"
pick_rc=$?
```

`pick_rc=1` is this invocation's own expected, non-error shape (see the script's own header
comment) — treat it as a normal result, never a failure. Parse `$pick_listing` (one row per
line: `{display name}  ({id})  [creator|member]`) and carry the result forward to Stages 7-9 as
the **Project binding** candidate surface, applying the same exactly-one-or-refuse discipline
Stage 5 already applies to collaborator resolution — never silently guessed:

- **Exactly one row**: that row's id (`binding_project_id`), display name
  (`binding_project_name`), and creator/member tag are the bind target used throughout Stages 7,
  9, 10, and 11.
- **Zero rows**: UNAVAILABLE (Stage 8) — the caller is on no shared project at all. State,
  verbatim, that creating a fresh project is still available, but only by the user's own hand,
  run outside this skill:
  ```
      bash .claude/scripts/sapience-project-bind.sh --name "<display name>" --confirm
  ```
- **More than one row**: UNAVAILABLE (Stage 8) — ambiguous, never guessed at. Name every
  candidate (display name and id) in the reason text and point at the disambiguating command the
  user can run themselves: `bash .claude/scripts/sapience-project-bind.sh --project "<name or
  id>" --confirm`.

Keep the prohibition in force in its correct, narrowed form: this skill never runs
`sapience-project-bind.sh` with `--confirm` anywhere except Stage 10's re-invocation of a
user-checked option, and never performs a bind unattended — the read-only pick above is the only
automatic invocation this stage makes. Proceed to Stage 2 either way.

## Stage 2: Read the Envelope

```bash
envelope="$(bash .claude/scripts/sapience-vault-read.sh)"
rc=$?
```

- `rc=1`: no Sapience token/host could be resolved at all (an environment error). STOP and
  report the failure; nothing downstream can run without credentials.
- `rc=2`: every one of the five top-level vault sources failed. STOP and report; this indicates
  a broken host/token, not a partial outage, and nothing useful can be drafted from a fully
  empty vault side.
- `rc=0`: at least one top-level vault source succeeded. Proceed, but read `envelope.errors[]`
  first and note every entry: each failed source degrades the surfaces that depend on it (e.g. a
  failed `docs` fetch means no `doc_bodies`/`doc_comments` either, which also disables the
  decision-log-row and doc-comment surfaces for this run — see Stage 9). Report every degraded
  surface in the final summary; never silently drop one.

Parse `$envelope` with `jq`. Its schema is `sapience-vault-read/1` (see
`sapience-vault-read.sh`'s own header comment for the full field list): `repo.{toplevel, name,
binding}`, `local.{git, state, events, errors, sessions}`, `vault.{projects, docs, doc_bodies,
doc_comments, project_notes, suggestions, notifications}`, and the top-level `errors[]` just
described.

## Stage 3: Draft Assembly

Compose the candidate update text from:

- `local.git.log` / `local.git.diff_stat` — what changed locally since the last read cursor.
- `local.state.completed_projects` — recently completed work in this repo.
- `local.events` / `local.errors` — recent lifecycle events and recorded errors.
- `local.sessions` — recent Claude Code session files, for context only (never read their full
  content here; the filenames/timestamps are enough to orient the draft).
- `vault.doc_comments` and `vault.notifications` — **read these before drafting anything.** The
  point of fetching them is that a draft should respond to a collaborator's latest comment or
  notification rather than talk past it. If a comment or notification exists that the draft
  text does not address, the draft is incomplete — revise it to address it explicitly.
- `vault.project_notes` and `vault.suggestions` — open threads and server-suggested next steps
  worth surfacing in the draft.

State plainly, in whatever summary accompanies the draft, that `doc_bodies`/`doc_comments` are
bounded to the envelope's own per-run unread-doc fetch limit — the draft is built from what this
one run's envelope carried, not from the vault's full history.

## Stage 4: Target Resolution

Apply the two rules from `domain/command-draft-and-picker.md` exactly as written there:

- **Most relevant doc** (for the doc-comment surface): among `vault.docs`, the doc with the
  greatest `activity.at` whose `activity.by` is not the running identity; else the doc with the
  greatest `updated`; tie-break on lexicographically smallest `slug`.
- **Decision-shaped** (gates the decision-log-row pre-check): true iff the draft text matches
  the documented case-insensitive marker set, or `local.git.log` contains a commit subject
  matching `^task [0-9]+: (create implementation plan|complete implementation)$`.

If no doc resolves at all (e.g. `vault.docs` is `null` because that source failed, or the
project has no docs), the doc-comment and decision-log-row surfaces are both UNAVAILABLE for
this run (Stage 9) — never guessed or defaulted to a fabricated slug.

The decision-log row's own target is specifically the project's decision-log doc (the doc whose
body opens with a one-line-per-decision table header), not the "most relevant doc" computed
above — resolve it by matching that header text among `vault.doc_bodies`, falling back to
UNAVAILABLE if it cannot be identified from what this run's envelope carried.

## Stage 5: `--message <Name>` — Resolve a Named Collaborator

Only when `mode=message` with a `name` given. Resolve the roster directly: source
`.claude/scripts/lib/sapience-api-lib.sh`, call `sapience_api_init`, then
`sapience_get "/v1/people"`, which returns `{ok, people: [{id, name, ...}], count, me, me_id}`.
Match `name` case-insensitively against each `people[].name`.

- Exactly one match: that person's `id` is the DM target.
- Zero or more than one match: **STOP** and report the ambiguity or absence by name — never
  silently fall back to the only connection, even when the roster has exactly one entry.

## Stage 6: `--message` With No Name — the Collaborator Picker

Only when `mode=message_picker`. Resolve the roster the same way as Stage 5, then present a
single-select `AskUserQuestion` (D8 — this is a SEPARATE, earlier question from the Stage 9
approval picker; the two are deliberately never merged):

```json
{
  "question": "Which collaborator should this update be sent to?",
  "header": "Collaborator",
  "multiSelect": false,
  "options": [
    {
      "label": "{person.name}",
      "description": "{short context, e.g. shared project name or last activity, if known}"
    }
  ]
}
```

The chosen person's `id` becomes the DM target, exactly as in Stage 5. If the roster is empty,
report that plainly and proceed without a DM candidate surface at all (not as an UNAVAILABLE
option — there is no collaborator to address).

## Stage 7: Preview Every Candidate Surface

For each candidate surface that resolved a target in Stage 1 or Stages 4-6, build its exact
`sapience-publish.sh` (or, for the Project binding surface, `sapience-project-bind.sh`) argument
vector and run it WITHOUT `--confirm`, capturing stdout: that is the literal payload (D6) — the
SAME construction path the confirmed write in Stage 10 reuses, so this is never a second,
hand-written preview string.

- **Project binding** (only when Stage 1's pick resolved exactly one row — never when it is
  UNAVAILABLE):
  ```bash
  project_binding_preview="$(bash .claude/scripts/sapience-project-bind.sh --project "$binding_project_id")"
  ```
  Its dry-run output is the literal `{"repo": "<slug>"}` link payload (D2) — the SAME
  construction path Stage 10's confirmed call reuses.
- **Doc comment** (when a target doc resolved in Stage 4):
  ```bash
  doc_comment_preview="$(bash .claude/scripts/sapience-publish.sh doc-comment "$target_slug" --body "$draft_comment_body")"
  ```
- **Decision-log row** (only attempted when Stage 4's decision-log doc resolved; D5's fallback
  applies here): if the decision-log doc's current body is not already present in
  `vault.doc_bodies`, obtain it by sourcing `.claude/scripts/lib/sapience-api-lib.sh`, calling
  `sapience_api_init`, then `sapience_get "/v1/docs/${decision_log_slug}"` directly — reusing the
  shared credential/host precedence, never re-deriving it, and never printing the token. On
  failure, mark this surface UNAVAILABLE with the failure reason and skip the rest of this
  bullet entirely (never fabricate or send an empty body). On success, append one row to the
  decision-log table (date, what was decided, who decided, a link to the discussion) and write
  the FULL proposed body — the current body plus the appended row — to a scratch file via
  `mktemp`:
  ```bash
  proposed_body_file="$(mktemp)"
  printf '%s' "$proposed_decision_log_body" > "$proposed_body_file"
  decision_row_preview="$(bash .claude/scripts/sapience-publish.sh doc-version "$decision_log_slug" --body-file "$proposed_body_file")"
  ```
  This preview call itself performs a real `GET` to resolve `base_rev` even under dry-run (a
  known, pre-existing cost of this subcommand, not something to avoid or work around).
- **Repo-tagged KOs** (always attempted; this is the only surface requiring no prior target
  resolution beyond the binding gate): build the inherited-bound set of 3-8 candidate notes from
  the draft's own findings, then preview the single batched call:
  ```bash
  ko_preview="$(bash .claude/scripts/sapience-publish.sh ko --note "$note_1" --note "$note_2" ...)"
  ```
- **DM** (only when a collaborator id resolved in Stage 5 or 6):
  ```bash
  dm_preview="$(bash .claude/scripts/sapience-publish.sh dm --to "$collaborator_id" --body "$draft_dm_body")"
  ```
  This subcommand's own dry-run prints BOTH of its sequential writes' payloads in one call
  (the DM itself, then the resulting conversation's first comment) — capture the whole thing as
  one preview, never split it.

Print every captured preview to the transcript now, in full, before Stage 9's picker — option
descriptions below can only carry an excerpt, never the full text, so the full text must already
be visible above the picker.

## Stage 8: Option Construction (One Site, Marker-Bracketed)

<!-- askuserquestion-option-construction: sapience-approval-picker -->

Build the option list for Stage 9 here, and nowhere else in this file. At most five options
exist (one per candidate surface); this never needs batching, tiering, or a "Select all" option,
because the measured ceiling is five. Pre-check defaults, exactly as
`domain/command-draft-and-picker.md` states them, with the Project binding row (new in this
phase) following the same table discipline:

| Option | Included when | Pre-checked when |
|--------|----------------|-------------------|
| Project binding | No link file exists (Stage 1) — included whether the pick resolved exactly one row or hit a zero/ambiguous-row UNAVAILABLE state, the reason stated either way | Never — the role note must be read before binding to someone else's project is a known choice |
| Doc comment | A target doc resolved in Stage 4 | Always (when included) |
| Decision-log row | The decision-log doc resolved AND its body was obtainable (Stage 7) | Stage 4's decision-shaped test is true |
| Repo-tagged KOs | Always | Always |
| DM | A collaborator id resolved (Stage 5 or 6), i.e. `--message` was passed | Always (when included) |

A surface that was attempted but hit a D5-class failure (body unobtainable, target
unresolvable) is still listed, labeled UNAVAILABLE with the failure reason in its description,
and is not selectable — `AskUserQuestion` cannot express "disabled," so phrase its label to make
inclusion-without-selectability obvious (e.g. `"Decision-log row — UNAVAILABLE"`) and its
description to state why, never silently dropping the row.

<!-- /askuserquestion-option-construction -->

## Stage 9: The Single Approval Picker

Exactly one `AskUserQuestion` call, covering every surface built in Stage 8 in one shot:

```json
{
  "question": "Which of these should actually be sent to the vault? Full payloads are printed above.",
  "header": "Sapience Approval",
  "multiSelect": true,
  "options": [
    {
      "label": "Project binding — {binding_project_name}",
      "description": "{role note: creator -- notes flow to the collaborator without a per-note confirm | accepted member -- notes land as suggestions only the project's author sees until confirmed} — full payload printed above. UNAVAILABLE and not selectable when Stage 1's pick found zero or more than one candidate (reason stated above)."
    },
    {
      "label": "Doc comment on {target_slug}",
      "description": "{first ~80 chars of doc_comment_preview's body} — full payload printed above"
    },
    {
      "label": "Decision-log row on {decision_log_slug}",
      "description": "{short excerpt of the appended row} — full payload printed above"
    },
    {
      "label": "Repo-tagged KOs ({n} note(s))",
      "description": "{first note's text, truncated} + {n-1} more — full payload printed above"
    },
    {
      "label": "DM to {collaborator_name}",
      "description": "{first ~80 chars of draft_dm_body} — full payload printed above"
    }
  ]
}
```

There is no delete API and no post-write review gate on any of these five surfaces — a confirmed
write here is permanent, which is the entire reason this picker is single, mandatory, and
payload-literal rather than summary-based (see `domain/command-draft-and-picker.md`'s "Why the
Picker Is Mandatory and Single").

## Stage 10: Confirmed Execution

For each option the user checked in Stage 9, re-invoke the IDENTICAL argument vector built in
Stage 7 with `--confirm` appended — never a re-derived or re-typed vector:

```bash
bash .claude/scripts/sapience-project-bind.sh --project "$binding_project_id" --confirm
bash .claude/scripts/sapience-publish.sh doc-comment "$target_slug" --body "$draft_comment_body" --confirm
bash .claude/scripts/sapience-publish.sh doc-version "$decision_log_slug" --body-file "$proposed_body_file" --confirm
bash .claude/scripts/sapience-publish.sh ko --note "$note_1" --note "$note_2" ... --confirm
bash .claude/scripts/sapience-publish.sh dm --to "$collaborator_id" --body "$draft_dm_body" --confirm
```

The KO surface issues exactly ONE `ko` invocation carrying every confirmed note via repeated
`--note` (D7) — never one call per note. The note count is bounded to the inherited
postflight-wrapup 3-8-note-per-task range (HARD CONSTRAINT 2); this skill adds no second,
independently-sized cap of its own.

## Stage 11: Outcome Reporting

Report each confirmed surface's result distinctly — never a single pooled "done" line, because
the five surfaces have five different success shapes:

- **Project binding**: one of three outcomes, named explicitly — written and registered (the
  link route returned a 2xx `ok: true`); written locally only, because the server returned 404
  and does not read it yet; or refused with nothing written, because the caller has not joined
  the project (403). In every case, relay the invocation's own last line of output verbatim as
  this skill's closing instruction for this surface (the exact file to commit, or that nothing
  was written on the 403 refusal) — never a different path invented here.
- **Doc comment**: written, with the returned `hash`/`n`, or a named failure.
- **Decision-log row** (`doc-version`): one of its four verified outcomes, named explicitly —
  `409 head_moved` (refused, nothing written, the doc changed since `base_rev` was fetched),
  `202` (proposed, awaiting the doc owner — this is NOT the same as saved), `404 share_gone`
  (refused, a shared slug with no existing document), or `2xx` (saved, with the new `rev`).
- **Repo-tagged KOs**: the `written` count and the resolved project key, or a named failure
  (`set_aside`, `gated`, or a non-`ok` response — never treated as success).
- **DM**: its two sequential writes reported in order (the DM itself, then the resulting
  comment), naming whether a new conversation was created or an existing one was reused.

A confirmed write is never retried, in any of the five cases above, including a failure: there
is no delete API, so a retry on an ambiguous or failed response risks duplicating a record that
cannot be removed. Report the failure and stop; do not re-issue the same `--confirm` call.

## Stage 12: Empty Selection

Zero checked options in Stage 9 is a legitimate, clean outcome: write nothing, issue no
`sapience-publish.sh --confirm` calls at all, and report plainly that nothing was sent. Never
re-prompt the picker — an empty selection is a decision, not an error.

