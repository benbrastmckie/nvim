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

If `$link_file` does not exist (or is not valid JSON): **STOP here.** This repository has no
Sapience project binding yet. Report to the user, verbatim, the exact command they must run
themselves to create one:

```
No Sapience project binding found at {link_file}.

Creating a binding shares a fresh project with a collaborator -- an outward-facing mutation
that notifies them -- so this command never does it autonomously (HARD CONSTRAINT 5 in the
governing plan). Run this yourself when ready:

    bash .claude/scripts/sapience-project-bind.sh --name "<display name>" --confirm
```

Never run `sapience-project-bind.sh` from this skill, in any mode, with or without `--confirm`.
If the binding exists, proceed to Stage 2.

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

