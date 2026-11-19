# Command Draft Assembly and the Single Approval Picker

This note is the durable design record for `/sapience`'s draft-assembly heuristics and its one
mandatory approval picker. `skill-sapience` implements against this record rather than
re-deciding these rules inline; citation of this file's section names stands in for restating
the rationale.

## The Four Candidate Write Surfaces

Every candidate surface the picker can offer maps 1:1 onto one `scripts/sapience-publish.sh`
subcommand. No other write mechanism exists, and no instruction surface names anything else as
a write path:

| Surface | `sapience-publish.sh` subcommand | Target |
|---------|-----------------------------------|--------|
| Doc comment | `doc-comment <slug> --body ...` | The most relevant doc (see below) |
| Decision-log row | `doc-version <slug> --body-file ...` | The decision-log doc specifically |
| Repo-tagged KOs | `ko --note ... [--project <cid>]` | The bound project |
| DM to a collaborator | `dm --to ... --body ...` | Whoever `--message` named or the resolved pick |

## Pre-Check Defaults

- Doc comment: pre-checked whenever a target doc resolves (see "Most Relevant Doc" below).
- Decision-log row: pre-checked only when the assembled draft is decision-shaped (see
  "Decision-Shaped" below); otherwise present but unchecked, or absent if no decision-log doc
  resolves.
- Repo-tagged KOs: pre-checked by default.
- DM: present and pre-checked only when the run was invoked with `--message`; otherwise absent
  from the option set entirely, not merely unchecked.

## Most Relevant Doc (a rule, not a judgment)

Among the bound project's docs in the read envelope's `vault.docs`: pick the doc with the
greatest `activity.at` whose `activity.by` is NOT the running identity. If no such doc exists,
pick the doc with the greatest `updated`. Break any remaining tie by lexicographically smallest
slug. Never hardcode a slug — every run re-derives this from the live envelope.

## Decision-Shaped (a rule, not a judgment)

The assembled draft is decision-shaped iff EITHER of the following holds:

- The draft text matches a documented, case-insensitive marker set: `decided`, `we will`,
  `going with`, `chose`, `settled on`.
- `local.git` since the read cursor contains a commit subject matching
  `^task [0-9]+: (create implementation plan|complete implementation)$`.

Otherwise it is not decision-shaped. The decision-log-row option is pre-checked only when this
test is true.

## Literal Payload Discipline

Each candidate surface's preview is produced by invoking the identical
`sapience-publish.sh` subcommand and argument vector WITHOUT `--confirm`, and the confirmed
write re-invokes that exact vector with `--confirm` appended — never a second, hand-written
preview string. The full payload text each dry-run prints is shown in the transcript immediately
before the picker; each option's own `description` carries only a short excerpt plus a pointer
to that printed payload, because `AskUserQuestion` option descriptions are length-limited and
cannot hold the full text themselves.

## Decision-Log Row Body Fallback

The decision-log row needs the target doc's current body to append to. When that body is not
already present in the read envelope's `doc_bodies` map (bounded to the envelope's own per-run
unread-doc fetch limit), obtain it by sourcing `scripts/lib/sapience-api-lib.sh` directly and
calling its GET helper against `/v1/docs/<slug>` — reusing the shared credential/host
precedence rather than re-deriving it, and never printing the token. On failure, the
decision-log-row option renders UNAVAILABLE with the failure reason stated; it is never offered
with a fabricated or empty body.

## The KO Surface Issues Exactly One Call

Every confirmed KO note is passed via repeated `--note` flags in a single `ko` invocation, which
POSTs all of them together. The picker never issues one `ko` call per note. The note count
inherits the existing postflight 3-8-note-per-task bound; this surface adds no second,
independently-sized cap of its own.

## Option-Construction Site

<!-- askuserquestion-option-construction: sapience-approval-picker -->

The picker's option objects are built in exactly one block inside `skills/skill-sapience/SKILL.md`,
bracketed by the matching marker comment pair shown above, so a later extraction of a shared
`AskUserQuestion` option renderer can find and absorb this site without hunting for scattered
call sites. No other block in either new instruction surface constructs picker options.

<!-- /askuserquestion-option-construction -->

## Why the Picker Is Mandatory and Single

There is no delete API for this vault: every confirmed KO and doc-version write is permanent,
and each bypasses the vault's own `auto_approve:false` review gate (that gate exists for writes
routed through other paths; a direct, confirmed `sapience-publish.sh` call is not staged for
later review). The approval picker is therefore the only safety control in front of an
irreversible write, which is why it is single (one `AskUserQuestion` call covering every
candidate surface in one shot), mandatory (the run always reaches it before any confirmed write),
and payload-literal (it shows the exact text that would be written, never a summary that could
drift from it).

## The Dark Migration Path

A repo-to-project binding mechanism exists server-side but is confirmed OFF for the credential
this extension currently uses: a probe carrying a bogus project identifier returned a normal
answer with none of the markers an enabled binding check would add, and the installed MCP
client's own source has zero references to that identifier field. This design treats that path
as the eventual target, not a rejected alternative: migrating onto it is a change inside
`scripts/sapience-publish.sh` and `scripts/sapience-vault-read.sh` themselves (how the project
key is resolved and sent), never a change to `/sapience`'s command grammar or to this picker's
shape. Nothing here forecloses that migration.
