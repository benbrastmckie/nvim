# Injection-Site Scoping

Measured, not inferred: whether each primary-session injection site transmits a repository
identifier, and whether the server honors it. This file is the single source of truth for that
measurement; `per-repo-scoping.md` and `vault-model.md` point here rather than restating it.

## The Three Primary-Session Sites, By Name

| Hook | Deployed command | Endpoint(s) | Sends a repository identifier? | Server honors it? |
|------|-------------------|-------------|----------------------------------|--------------------|
| `SessionStart` | `python3 "$HOME/.sapience/mcp.py" --briefing-text` | `GET /briefing` + `GET /v1/outstanding` | No — neither client call sends a body at all | N/A — `/v1/outstanding` is a cross-project aggregate by product design (its own tool description: grouped by project, across projects) |
| `UserPromptSubmit` | `python3 "$HOME/.sapience/sapience_cli.py" hook prompt` | `POST /v1/cli/context` | Yes — `project=project_of(cwd)`, which resolves this repository's cwd to a slug via `config.json`'s `capture.projects` entries | **Ignored by the server, measured** (see Foreclosure 1) |
| `PreToolUse` | `python3 "$HOME/.sapience/sapience_cli.py" hook tool` | `POST /v1/cli/context` | No — the body carries only `file=<path>`, never a project | N/A |

These three are not a uniform surface: exactly one of them sends a repository identifier at all,
and that one is ignored. `SessionEnd` and `Stop` are reporting surfaces (a one-line receipt / a
one-line effect summary), not injection sites, and are out of scope for this note.

## The Fourth Path, Deliberately Contrasted

`sapience-retrieve.sh` calls `GET /v1/search` with a `source=[repo:<slug>]` filter and **is**
scoped — but it feeds dispatched subagent prompts only, never the primary session, so it is not
an alternative to the three sites above. See `per-repo-scoping.md` for its mechanism; it is not
restated here.

## Foreclosure 1 — `project` Is Ignored on the Hook-Facing Endpoint

Two otherwise-identical `POST /v1/cli/context` calls, differing only in `project` (a real,
confirmed slug vs. a nonexistent sentinel string), return byte-identical `text`/`visible`
bodies — including a cross-repo false claim about another repository's roadmap, reproduced
inside this one. This is a direct measurement, not an inference carried over from the unrelated
`/v1/search` endpoint's own (separately documented) `project=` dead end: `/v1/cli/context` is the
endpoint both `UserPromptSubmit` and `PreToolUse` actually call, and it was tested on its own
terms.

## Foreclosure 2 — No Per-Item Attribution to Filter or Label By

The response envelope's top-level keys are `enabled`, `event`, `level`, `ms`, `src`, `status`,
`text`, `visible`. Each rendered item inside `text` carries a title, a date, and a
`(matched: ...)` keyword-match tail — never a project or source tag, at the envelope level or
per item. Consequence: a local wrapper around the hook's own stdout has no attribution signal to
filter or label by. There is nothing recoverable to key a client-side mechanism on.

## The Ruling: Label, Never Suppress — And Neither Is Reachable

Suppressing any of the three hooks is rejected: the cross-corpus abstraction class (an
abstraction belonging to no single repository) is the most valuable part of the channel, and
suppressing the hooks would cost it along with the `SessionStart` outstanding-board feature,
for a primary session that has no other path to this content (the fourth path above feeds only
dispatched subagents). Labelling by source is the preferred alternative in principle, but it is
unreachable today: Foreclosure 2 establishes there is no attribution signal to label with. So
neither remedy is available from this repository, for either of two independent reasons:

- No working filter parameter exists on `POST /v1/cli/context` (Foreclosure 1).
- No per-item attribution exists to label by, even if a filter did exist (Foreclosure 2).

This gap is not bounded to the agent-tagged write population. Documents shared by other people
(provenance of the form `people <name> | shared by <name> <timestamp> | doc {...}`) belong to no
repository at all, and are equally unlabellable by this same reasoning — there is nothing project-
shaped in their provenance to filter or label on either.

## Owner Action 1 — The Vendor Ask

This is OWNER ACTION: a message to the vendor, never a local file change. `~/.sapience/mcp.py`
and `~/.sapience/sapience_cli.py` self-update daily (both carry same-day modification times and
an update marker on this machine), so a local hand-patch to either file is not a durable
alternative — it would be overwritten by the next automatic update.

> On `POST /v1/cli/context`, the `project` field the client already sends on every
> `UserPromptSubmit` call (`sapience_cli.py`'s `hook prompt` handler) is silently ignored:
> a request with `project=<real project name>` and an otherwise-identical request with
> `project=<a nonexistent sentinel string>` return byte-identical `text`/`visible` bodies.
> Please either (a) honor `project` as a hard pre-filter on `/v1/cli/context` (matching
> `/v1/search`'s existing `source=` pre-filter semantics), or (b) reflect the `project` field
> that `/extract`'s per-chunk metadata already carries (`upload.py`'s `_chunk()`, which sets
> `'project': m['project']` on every transcript chunk) into each resulting knowledge object's
> authored `provenance` string, so a `source=[repo:<tag>]` read-side filter — already proven
> to work for explicitly-tagged writes — can reach transcript-extracted content too. Either
> change, alone, would let a per-repository client stop receiving another repository's
> specific factual claims without losing cross-project content a caller does not filter for.
> Separately: `GET /v1/outstanding` (the `SessionStart` hook's cross-project board) currently
> takes no project parameter at all, yet its own response is already grouped by project
> server-side — exposing that same grouping as an optional filter would let a caller ask for
> "this project first" without losing the cross-project tally entirely.

## Owner Action 2 — The Machine-Wide Duplicate Hook Surface

This is also OWNER ACTION, and it is sited in a different repository (`~/.dotfiles`) that this
source store must not edit. Exact, runnable inspection commands the owner can paste:

```bash
jq -r '.hooks | keys' "$HOME/.claude/settings.json"
jq -r '.hooks.SessionStart' "$HOME/.claude/settings.json"
jq -r '.hooks.UserPromptSubmit' "$HOME/.claude/settings.json"
jq -r '.hooks.PreToolUse' "$HOME/.claude/settings.json"
```

These same hook commands currently fire from `$HOME/.claude/settings.json` in every repository
on this machine, regardless of any one repository's own per-repo extension activation state.
Retiring that duplicate is owned by the `retire_machine_wide_sapience_surface` work sited in
`~/.dotfiles` — a different repository this source store must not edit, per
`rules/source-store-deploy-boundary.md`'s task-siting rule.

## Candidate Follow-Up, Recorded Not Built

A claim-shape heuristic was considered as a locally-buildable partial mitigation: cross-check a
bulleted item that asserts a specific, countable identifier about "this repo" (a task number, a
roadmap task/topic count, a phase label) against this repository's own live
`specs/state.json`/`specs/ROADMAP.md` before passing it through, suppressing it, or relabelling
it as cross-project. It is recorded here as a candidate, deliberately **not built** in this
pass: it is approximate by construction (it can only catch claims shaped like a bare countable
fact) and carries a measured brittleness risk flagged independently in the research that
preceded this note. A future task scoping this heuristic should test it against a labelled set
of known-true and known-false examples before any rollout, given that risk.

## Verifying This Residual Is Still Current

`scripts/verify-sapience-context-scoping.sh` re-runs the Foreclosure 1 comparison on demand and
reports one of three outcomes (residual holds, residual lifted, inconclusive), so the day the
vendor ask above lands is detected rather than assumed. See that script's own header for usage.
