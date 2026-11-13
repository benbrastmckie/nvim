# Research Report: Task #606

**Task**: 606 - Scope Sapience context injection to the current repository so a session stops
receiving other repos' facts
**Started**: 2026-11-12
**Completed**: 2026-11-12
**Effort**: ~3 hours (research)
**Dependencies**: 600 (completed), 611 (completed), 612 (completed)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/sapience/**`, `specs/state.json`, `specs/ROADMAP.md`,
  `specs/611_*/`, `specs/612_*/`, `specs/600_*/`
- Live vendor files on this machine: `~/.sapience/sapience_cli.py`, `~/.sapience/mcp.py`,
  `~/.sapience/upload.py`, `~/.sapience/config.json` (keys only), `~/.claude/settings.json`
- Live HTTP calls to `https://app.spnc.ai/v1/cli/context` (the exact endpoint and body shape the
  deployed hooks use), reproducing the seed report's observed defect from inside this repository
**Artifacts**: `reports/02_injection-site-scoping-findings.md` (this file)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The three hook sites are already fully enumerated and the dispatch's own enumeration needed
  one correction, now made**: only `UserPromptSubmit` (`sapience_cli.py hook prompt`) sends a
  repository identifier at all. `SessionStart` (`mcp.py --briefing-text`) sends none — its two
  backing calls, `GET /briefing` and `GET /v1/outstanding`, take no project/cwd parameter in the
  client code, by design (the outstanding board is explicitly a cross-project aggregate).
  `PreToolUse` (`sapience_cli.py hook tool`) sends none either, as the dispatch already stated.
- **New, directly measured finding — the central result of this pass**: `POST /v1/cli/context`,
  the one endpoint behind both `UserPromptSubmit` and `PreToolUse`, ignores the `project` field
  it is sent. A live call replaying the exact production request shape with `project=nvim` (this
  repo's real, confirmed slug) and a second call with `project=zzz-nonexistent-sentinel-project`
  returned byte-identical `text`/`visible` bodies, including the live cross-repo false fact
  `"Roadmap a780b271a contains 90 tasks across 10 topics"` — the identical false headline count
  the seed report observed in a different repository, now reproduced inside this one. This closes
  the seed report's open research question "does `project=` work on the hook-facing endpoint?"
  with a direct no, not an inference from the unrelated `/v1/search` endpoint.
- **New finding that forecloses the "client wrapper" lever entirely**: the `/v1/cli/context`
  response carries no per-item source/project field anywhere (`enabled, event, level, ms, src,
  status, text, visible` are the only top-level keys; the `text` block's bulleted items carry a
  title, a date, and a `(matched: ...)` keyword-match annotation — never a project or source
  tag). A local wrapper has nothing to filter *by attribution*, which settles the dispatch's own
  conditional ("viable ONLY if the output carries recoverable source attribution") in the
  negative, by direct test rather than by argument.
- **Acceptance criterion 4's local half is already closed** — by task 611, not by this task. The
  write-side source-store audit confirms `sapience-remember.sh` tags every write it makes, and no
  instruction surface under the source store names an MCP write tool as a prescribed path.
  Nothing further is required here on the write side.
- **Activation gating (task 612) and content scoping (this task) are different axes, and task
  612 does not substitute for this task.** Task 612 makes loading the extension the switch for
  whether Sapience runs in a given repo at all (grants, hooks, per-project MCP registration). This
  repo has the extension loaded and Sapience correctly "on" here — and the live reproduction
  above happened *inside this correctly-activated repo*, proving the content-scoping defect
  survives activation gating entirely. Task 612's own summary also names an unfinished companion
  (`retire_machine_wide_sapience_surface`, in `~/.dotfiles`, a different repository) that would
  retire a redundant user-level copy of the same five hooks; until that companion lands, the
  hooks fire from `~/.claude/settings.json` in every repo on this machine regardless of
  per-repo activation, which is a second, independent reason the defect is not repo-gated today.
- **No mechanism available to this repository can satisfy acceptance criterion 1 for the three
  hook sites.** There is no working filter parameter and no recoverable attribution to label
  with. The only lever that can actually close the gap is server-side (acceptance criterion 5's
  vendor ask, sharpened below to name the correct endpoint). A claim-shape heuristic (flag a
  bulleted item whose text asserts a specific countable/numbered fact about "this repo" that
  live `specs/state.json`/`specs/ROADMAP.md` can contradict) is the one *locally buildable*
  partial mitigation identified, and it is recommended as a separately-scoped, exploratory
  follow-up — not as this task's deliverable — given its measured brittleness risk.

## Context & Scope

This is a pure read-side / content-scoping investigation. The sibling write-side task (611) and
the activation-gating task (612) are both complete; this report treats their output as settled
fact (re-verified live below) rather than re-deriving it. The scope is exactly the three
primary-session injection sites named in the dispatch — `SessionStart`, `UserPromptSubmit`,
`PreToolUse` — plus the vendor-ask deliverable the dispatch's own SCOPE section assigns to
acceptance criterion 5. The already-fixed dispatch-prompt path (`sapience-retrieve.sh`) is out of
scope, as is anything requiring an edit under `~/.sapience/**` or `~/.claude/settings.json`
(owner-only, and `~/.sapience/{mcp,sapience_cli}.py` self-update daily, confirmed live — both
files carry today's date and an `update.log`/`.auto_update.json` pair).

### Premise Re-Validation (Carried-Figure Discipline)

| Carried claim (dispatch description) | Verdict |
|---|---|
| L1/L92: source store is `agent-system/extensions/sapience/**`; `.claude/**` is a disposable deploy artifact | **CONFIRMED**, unchanged. `.claude-extensions.json` resolves this extension's `source_dir` to `agent-system/extensions/sapience`; `.claude/settings.local.json` is the merged deploy output, re-confirmed live by reading both files in this session. |
| L43/L60-62: `upload.py`'s `_chunk()` sends `'project': m['project']` at "line 236"; `memory_provenance()` at "upload.py:1781" | **CONFIRMED EXACT**, re-read live: `_chunk()`'s dict-build line is line 236 verbatim; `memory_provenance()` is called at line 1781. `upload.py` does not self-update (file timestamp 2026-11-03, no update marker), unlike the two files below, so these line numbers are stable. |
| L50: "two of the three hooks resolve the current repository from cwd and transmit it internally... `sapience_cli.py:457` (session)... `sapience_cli.py:466` (prompt)" | **CORRECTED, not confirmed.** `sapience_cli.py` self-updates daily (confirmed: both `sapience_cli.py` and `mcp.py` carry today's modification time and an `update.log`/`.auto_update.json` pair) and is now 906 lines, not ~470; the cited line numbers do not exist at those positions today (current equivalents: `project=pj` at line 599, `project=project_of(cwd)` at line 605). More importantly, **the "session" branch cited is dead code for this repository's deployed `SessionStart` hook.** The deployed `SessionStart` command is `python3 mcp.py --briefing-text` (confirmed in both this repo's merged `.claude/settings.local.json` and in `~/.claude/settings.json`) — a *different* vendor script that never calls `sapience_cli.py`'s `hook('session', ...)` path at all. `mcp.py --briefing-text` calls `GET /briefing` and `GET /v1/outstanding`, and neither client call passes a `project`, `cwd`, or any folder-derived argument (confirmed by reading `get_briefing()`/`get_outstanding()`, which call `api(path, timeout=...)` with no body). **Corrected count: exactly one of the three deployed hooks (`UserPromptSubmit`) sends a repository identifier, not two.** This correction is load-bearing for §"Findings" below and for the vendor ask in Recommendations. |
| Acceptance criterion 4's local half ("every write path the source store owns is repo-tagged") | **CONFIRMED CLOSED**, by task 611 (completed; re-verified live via `rules/sapience-write-path.md`, `domain/review-gate-boundary.md`'s Write-Tool Disposition table, and `scripts/sapience-remember.sh`'s unconditional `provenance = "[repo:<slug>] via sapience-remember.sh..."`). No further write-side action is in scope for this task. |

## Findings

### 1. Corrected site-by-site inventory

| Site | Deployed command | Endpoint | Sends a repo identifier? | Server honors it? |
|---|---|---|---|---|
| `SessionStart` | `python3 mcp.py --briefing-text` | `GET /briefing` + `GET /v1/outstanding` | **No** — neither client call sends a body at all | N/A; `/v1/outstanding` is explicitly a cross-project aggregate by product design (its own MCP tool description: "cross-project outstanding-work board... grouped by project") |
| `UserPromptSubmit` | `python3 sapience_cli.py hook prompt` | `POST /v1/cli/context` | **Yes** — `project=project_of(cwd)`, where `project_of()` resolves this repo's cwd to the literal string `nvim` via `config.json`'s `capture.projects` entry (confirmed: `path_prefix: /home/benjamin/.config/nvim`, `name: nvim`) | **No — directly measured below** |
| `PreToolUse` | `python3 sapience_cli.py hook tool` | `POST /v1/cli/context` | No — body carries only `file=<path>` | N/A |

This table supersedes the dispatch description's "two of three transmit the project" framing
(see Premise Re-Validation): it is one of three, and that one is ignored.

### 2. Live reproduction: `project=` is dead on `POST /v1/cli/context`, not only on `/v1/search`

The prior art (archived task `sapience_per_repo_storage_and_injection`) established that
`project=` is a dead end on `/v1/search`. The seed report inferred, but did not test, that the
same is true of `/v1/cli/context` — the endpoint the two live hooks actually call. This pass
tested it directly, replaying the production request shape:

```
project=nvim (real, confirmed slug) vs project=zzz-nonexistent-sentinel-project-93021
same prompt, same event='prompt', same level='rich'
-> HTTP 200 / HTTP 200, text_len=886 / text_len=886, byte-identical bodies
```

The returned block (verbatim, both calls identical):

```
<sapience>
Sapience ▸ 2 rules · 2 facts
  ● rule  Decision pivot for 761                                    Nov 4
      If 761 blocks on open mathematics rather than a ruling, the pivot is to run (P1) at Base...
  ● rule  Roadmap pivot condition                                   Nov 4
      The pivot to 559's (P1) at Base is licensed because 761 has blocked on open mathematics...
  ○ fact  Open Task Batching                                        Nov 4
      As of the current check, of 77 open tasks, none are unbatched and unnamed.
  ○ fact  Roadmap state                                             Nov 4
      Roadmap a780b271a contains 90 tasks across 10 topics.
</sapience>
```

Checked against this repository's own live state, in this same session:

| Injected claim | Live check in this repo (nvim) | Result |
|---|---|---|
| References to task "761" | `jq` over `state.json`: 0 entries with `project_number==761`; no `specs/761_*` directory | **FALSE for this repo** — this repo's highest task number is 613 |
| "Roadmap ... contains 90 tasks across 10 topics" | `jq` over `active_topics`/open `active_projects`: 9 topics, 131 open tasks | **FALSE for this repo** |

This is the exact same false-claim signature (a task number from another repo's numbering
space, a stale roadmap task/topic count) the seed report observed in
`~/Projects/Logos/Verification` — reproduced live, in this repository, through the one hook that
does send a project identifier, which the server ignores. This directly answers the seed
report's §6 open question 1 ("is `project=` ignored outright, honoured only for tagged KOs, or
defeated by the untagged majority?") for this endpoint: it is ignored outright, regardless of
tagging state.

### 3. No per-item attribution exists to filter or label by

The full response envelope's top-level keys (one real call, captured for this report): `enabled,
event, level, ms, src, status, text, visible`. `status` carries only aggregate counters
(`{'open': 0, 'overnight': '...', 'relevant': 2}`); `src` names the backend's own strategy
(`search`); nothing names a project, repository, or source for the block as a whole or for any
one of its bulleted items. Each bulleted item in `text` carries a bold title, a date, body text,
and a `(matched: <keywords>)` tail — the client's own keyword-match explanation, never a
provenance or project tag.

This directly tests, and settles in the negative, the dispatch's own conditional for the
"wrapper filtering vendor stdout" lever: *"Viable ONLY if the output carries recoverable source
attribution — establish that before costing it."* It does not. A hypothetical wrapper around
`sapience_cli.py hook prompt`'s stdout has no project/source signal available to filter on, so it
cannot distinguish a same-repo item from a cross-repo one by attribution. This is now a measured
fact, not an inference from the write-side vault-model census.

### 4. Task 611 (write-side) and task 612 (activation) do not reach this defect

- **Task 611** makes every source-store-owned *write* carry `[repo:<slug>]` in `provenance`, so
  `sapience-retrieve.sh`'s `GET /v1/search?source=...` read can filter on it. The three hook
  sites never call `/v1/search` or read `provenance` at all — they call `/v1/cli/context`, whose
  response (§3) carries no field the `source=` filter, or any filter, could key on. Tagging
  writes more thoroughly has **zero effect** on what the hooks inject, in either direction: a
  `[repo:nvim]`-tagged KO is exactly as visible to another repo's `UserPromptSubmit` hook as an
  untagged one, because the hook's own query path never looks at the tag.
- **Task 612** gates whether the extension's permission grants, these same five hook commands,
  and the per-project MCP registration are merged into a given repo's own `.claude/settings.local.json`
  at all. It is the right lever for "should Sapience run here," and it works as designed — this
  repo has the extension loaded, and the grants/hooks/registration are all present and verified
  (task 612's own summary; re-confirmed by this session's own read of `.claude/settings.local.json`).
  But §2's reproduction happened *inside this correctly-activated repository*, which proves content
  scoping is an orthogonal problem activation gating cannot solve.
- **Unfinished companion, in a different repository.** Task 612's summary names
  `retire_machine_wide_sapience_surface` (in `~/.dotfiles`) as the task that would retire the
  duplicate, machine-wide copy of these same five hooks that currently lives in
  `~/.claude/settings.json` (confirmed present there in this session, byte-for-byte the same
  `mcp.py --briefing-text` / `sapience_cli.py hook prompt` / `sapience_cli.py hook tool` commands).
  Until that companion lands — in `~/.dotfiles`, a repository this source store cannot edit, per
  `rules/source-store-deploy-boundary.md`'s task-siting rule — these hooks fire from the
  machine-wide file in every repo on this machine regardless of whether that repo's own
  `sapience` extension is loaded. This is a second, independent reason today's exposure is not
  bounded by per-repo activation, and it is outside this task's own edit surface to close.

### 5. The framing question (seed report §6.5 / dispatch's "should the framing change?") is open, not ruled

Nothing read in `sapience_cli.py`'s `_answer()`/`hook()` path, or in `mcp.py`'s
`briefing_text()`/`recommended_briefing_line()`/`position_briefing_lines()` construction, uses
"per your own KO" / "your earlier result" phrasing. The rendered `text`/`visible` strings this
pass captured are plain bulleted facts/rules with dates and match annotations, not framed as the
reader's own prior conclusion. It cannot be ruled out that the framing the seed report observed
came from a different code path (an MCP tool's own description string, or the calling model's
own paraphrase of injected context, independent of the hook's literal output) — this pass found
no evidence either way and does not have budget to chase it further. **Left explicitly OPEN**
rather than given a verdict this pass cannot support.

## Decisions

1. **Acceptance criterion 1 (no cross-repo factual claim, or label it) cannot be satisfied for
   any of the three hook sites by a mechanism available to this repository.** There is no working
   filter parameter (§2) and no recoverable attribution to label with (§3). This is now a
   measured conclusion, not a scoping assumption. The only lever that can close the gap is
   server-side (acceptance criterion 5).
2. **Suppressing the three hooks outright remains rejected**, re-confirmed rather than merely
   carried forward: it would cost the `SessionStart` outstanding-board feature and the
   `UserPromptSubmit` cross-corpus abstraction class entirely (criterion 2), for a primary session
   that — per the prior art — has no other path to this content (`sapience-retrieve.sh` feeds only
   dispatched subagent prompts, never the primary session).
3. **A claim-shape heuristic filter is the one surviving, locally-buildable partial mitigation**,
   and it is deliberately NOT adopted as this task's deliverable. It would need to parse
   `sapience_cli.py hook prompt`'s stdout (JSON `hookSpecificOutput.additionalContext`), identify
   bulleted items whose text asserts a specific, checkable count or identifier about "this repo"
   (a task number, a roadmap task/topic count, a phase label), and cross-check each against this
   repo's own live `specs/state.json`/`specs/ROADMAP.md` before passing it through unmodified,
   suppressing it, or re-labelling it as cross-project. This is approximate by construction (it
   can only catch claims shaped like the four false items the seed report observed, and the seed
   report itself flagged "too brittle or too lossy in practice" as its main risk) and is
   recommended as a separately-scoped, exploratory follow-up task — see Recommendations.
4. **The framing question is left open** (§5) rather than ruled on, for lack of evidence this
   pass could gather within its own hook-site scope.

## Recommendations

1. **File the vendor ask (acceptance criterion 5), sharpened to name the correct endpoint.**
   The dispatch's own SCOPE section already assigns this ask to criterion 5; this pass's §2
   finding sharpens its target from `/v1/search` (the prior art's endpoint) to `/v1/cli/context`
   (the endpoint the actual hooks call) and adds a directly-reproduced failing example. Exact,
   runnable text for the owner to send to the vendor:

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

   This is OWNER ACTION, not an agent edit: it is a message to the vendor, not a file change
   under this repository's control, and `~/.sapience/{mcp,sapience_cli}.py` self-update daily
   (confirmed live), so no local hand-patch to either file would survive to be a durable
   alternative.
2. **Document the measured residual in the source store**, which this pass's findings make more
   precise than what currently exists:
   - Add a fifth Hazards item to `per-repo-scoping.md` stating, in its own terms, §2-§3 above:
     `/v1/cli/context` ignores `project` entirely and returns no per-item attribution, so neither
     a read-side filter nor a client-side wrapper can scope `UserPromptSubmit`/`PreToolUse`
     content from this repository.
   - Correct `vault-model.md`'s "Local CLI's Exact Mode Inventory" section, which currently
     documents only `mcp.py`'s own CLI surface and does not mention `sapience_cli.py` or
     `/v1/cli/context` at all, even though `sapience_cli.py` backs two of the three hooks and is
     the actual site of this task's central finding.
   - Add a "Gap 5" entry to `README.md`'s "The Gaps This Extension Closes" section naming the
     unresolved content-scoping residual and pointing at the vendor ask above, so a future reader
     does not mistake the current (closed) Gaps 1-4 for a complete account.
3. **Scope the claim-shape heuristic filter as its own follow-up task, not this task's
   deliverable.** If pursued, its design should be tested against the seed report's own four
   false items and two true items (§2's reproduction gives a fifth, freshly confirmed false
   example) before any rollout, given the brittleness risk already flagged in both the seed
   report and this pass's Decisions §3.
4. **No further write-side action.** Acceptance criterion 4's local half is closed by task 611;
   this task need only reference it, not repeat it.
5. **No change to activation gating.** Task 612 already does the correct thing for the on/off
   question; the unfinished machine-wide companion (`retire_machine_wide_sapience_surface`) is
   correctly sited in `~/.dotfiles`, not this source store, per the task-siting rule, and should
   be tracked there, not absorbed here.

## Risks & Mitigations

- **Risk**: presenting the vendor ask as "the fix" could read as though this task has already
  closed the gap. **Mitigation**: the report and any resulting plan state plainly that, absent
  vendor action, no mechanism available to this repository can satisfy acceptance criterion 1 for
  the three hook sites — this is stated as a measured conclusion in Decisions §1, not softened.
- **Risk**: a future claim-shape heuristic filter could itself introduce new false
  positives/negatives (suppressing a true same-repo fact that happens to cite a number, or
  passing through a cross-repo claim phrased without a bare number). **Mitigation**: Recommendation
  3 scopes this as a separate, exploratory follow-up with an explicit pre-rollout test set drawn
  from the seed report's six labelled examples plus this pass's own reproduction, rather than
  folding it into this task's deliverable.
- **Risk**: the `~/.dotfiles` companion task's status is unknown from this repository (a
  different repo entirely) and could close the machine-wide duplicate-hooks gap independently of
  anything this task does, or could stall indefinitely. **Mitigation**: named explicitly in
  Findings §4 and Recommendations §5 as out of this task's edit surface and as a fact the user
  should independently confirm, rather than assumed to be either resolved or stalled.

## Context Extension Recommendations

- **Topic**: `sapience_cli.py` and the `/v1/cli/context` endpoint.
  **Gap**: `context/project/sapience/domain/vault-model.md`'s "Local CLI's Exact Mode Inventory"
  section documents only `~/.sapience/mcp.py`'s CLI modes; `sapience_cli.py` — the script backing
  `UserPromptSubmit` and `PreToolUse`, and the one this task's central finding concerns — is not
  mentioned anywhere in the source store's domain docs.
  **Recommendation**: extend `vault-model.md` (or add a new domain file) covering
  `sapience_cli.py`'s `hook session|prompt|tool|stop` modes, the `POST /v1/cli/context` endpoint
  they share, and the measured fact that its `project` field is ignored (see Recommendation 2
  above for the specific target file and section).
- **Topic**: the per-repo-scoping Hazards census's population count.
  **Gap**: `per-repo-scoping.md`'s Hazards section enumerates four KO populations by tagging
  status but does not yet record that the primary-session hook path has no scoping mechanism at
  all, independent of tagging.
  **Recommendation**: add the fifth Hazards item named in Recommendation 2.

## Appendix

### Search queries / commands used

```bash
# Dependency verification
jq -r '(.active_projects[]?,.archived_projects[]?) | select(.project_number==600 or .project_number==611 or .project_number==612) | {project_number,status,title}' specs/state.json

# Source store inventory
find agent-system/extensions/sapience -type f | sort

# Deployed settings (this repo and user level)
jq -r '.hooks.SessionStart' .claude/settings.local.json
jq -r '.hooks.SessionStart' ~/.claude/settings.json
jq -r '.hooks | keys' ~/.claude/settings.json

# Vendor file line checks (self-update drift)
grep -n "def hook\|def project_of\|body.update\|project=" ~/.sapience/sapience_cli.py
grep -n "def _chunk\|def memory_provenance\|'project'" ~/.sapience/upload.py
grep -n "def api\|def get_briefing\|def get_outstanding\|def briefing_text" ~/.sapience/mcp.py

# capture.projects entries (names/path_prefixes only, no secrets)
python3 -I -c "import json; d=json.load(open('/home/benjamin/.sapience/config.json')); [print(p.get('name'), p.get('path_prefix'), p.get('enabled')) for p in d['capture']['projects']]"

# Live reproduction against the real hook endpoint (token read from config.json, never printed)
python3 -I -c "
import json, urllib.request, urllib.error
cfg = json.load(open('/home/benjamin/.sapience/config.json'))
host, token = cfg['host'].rstrip('/'), cfg['token']
def post(body):
    req = urllib.request.Request(host + '/v1/cli/context', data=json.dumps(body).encode(), method='POST',
        headers={'Content-Type':'application/json','Authorization':'Bearer '+token,'User-Agent':'sapience-cli/1'})
    r = urllib.request.urlopen(req, timeout=8); return r.status, json.loads(r.read() or b'{}')
prompt = 'What is the current state of the roadmap, open tasks, and any recent decisions about Sapience scoping?'
for proj in ['nvim', 'zzz-nonexistent-sentinel-project-93021']:
    code, r = post({'event':'prompt','session_id':'test-'+proj,'level':'rich','view_lines':12,'prompt':prompt,'project':proj})
    print(proj, code, len(r.get('text','')))
"

# Live-state checks against the injected claims
jq -r '[(.active_projects[]?,.archived_projects[]?)|select(.project_number==761)]|length' specs/state.json
jq -r '"topics=\(.active_topics|length) open=\([.active_projects[]|select(.status!="completed")]|length)"' specs/state.json
```

### References

- `specs/606_scope_sapience_injection_to_current_repo/reports/01_seed-cross-repo-injection.md`
  (seed report; superseded in part by §1/§2 of this report, as noted inline)
- `specs/611_repo_tag_sapience_write_paths/plans/01_repo-tag-sapience-write-paths.md`,
  `specs/611_repo_tag_sapience_write_paths/summaries/`
- `specs/612_gate_sapience_activation_behind_extension/summaries/01_gate-sapience-activation-extension-summary.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/vault-model.md`
- `agent-system/extensions/sapience/rules/sapience-write-path.md`
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh`,
  `agent-system/extensions/sapience/scripts/sapience-remember.sh`
