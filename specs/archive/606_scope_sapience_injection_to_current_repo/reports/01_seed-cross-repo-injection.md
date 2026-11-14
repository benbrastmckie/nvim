# Seed Report: Sapience Cross-Repository Injection

**Kind**: seed report, not a research deliverable. Written by the session that observed the
defect, so the research phase need not re-derive what was already measured.
**Observed in**: a `/orchestrate` session in `~/Projects/Logos/Verification`, 2026-11-11.
**Claim marking**: every claim is VERIFIED (a command was run), REPORTED (read from an existing
artifact), or OPEN (not established — the research phase's job). The VERIFIED items are offered
so they need not be re-measured; anything OPEN is genuinely open. §5 contains the headline
finding and it **supersedes the simpler diagnosis that prompted this work** — read it before
designing anything.

---

## 1. What was observed

A session received, across its hooks, knowledge items of which five made checkable claims about
"this repo". Four were false.

| Injected claim | Check | Result |
|---|---|---|
| "…sweep produced a regression in `test-double-loading-check.sh`", carrying a **Recommended** action, attributed to a task numbered 435 | queried `active_projects` + archive; globbed the task dir | **FALSE.** No entry, no directory. Highest number in the repo is 290. |
| "the sanctioned fix is `reconcile-task-status.sh <N>`" for a task numbered 761 | same | **FALSE.** No entry, no directory. |
| "Phase 11.5 is currently a 'wall' (blocked), preventing progress into Phases 11.6, 11.7, and 12-18" | `grep -cE 'Phase 1[0-9]' specs/ROADMAP.md` | **FALSE.** Returns `0`. That file uses `Stage 0`–`Stage 5` plus named Tracks; no Phase numbering exists. |
| "Roadmap contains 90 tasks across 10 topics" | `jq` over `active_topics` and non-completed `active_projects` | **FALSE.** 50 open tasks, 12 topics. |
| "Tasks for agent-system must be filed locally in `~/Projects/BimodalLogic/specs/`" | `jq` over `.claude-extensions.json` `source_dir` values | **FALSE for this repo.** All resolve under `~/.config/nvim/agent-system/extensions/*`. |

A sixth, same class but path-shaped: an injection asserted the executing skill's base directory
was under `~/Projects/BimodalLogic/...` while it was in fact under
`~/Projects/Logos/Verification/...`.

Two aggravating circumstances, worth carrying into whatever ruling follows:

- **Timing.** The "Phase 11.5" item arrived on the *exact* user turn whose instruction was
  "update the roadmap". A confident false statement about "the roadmap" at the moment the roadmap
  is being hand-edited is the worst possible delivery moment; trusted, it would have written
  fiction into the file.
- **Framing.** Items are presented as the reader's own prior conclusions — "per your own KO",
  "Your earlier result on Oct 18 was…". A wrong item labelled as one's own settled conclusion
  attracts less scrutiny than one labelled as a retrieval. The framing raises the cost of each
  false item.

## 2. What was useful — the fix must not destroy this

The goal is scoping, not suppression. Same session, real value delivered:

- **The consolidated cross-corpus abstraction was a direct hit**: *"many apparent separate facts
  are the same defect recurring: a guard, sentinel, or verification checked at only one site,
  under one flag, or against a stale snapshot, so it passes while the claim it certifies is
  false."* That is exactly the defect the session then found (`check.sh: PASS` and exit 0 over a
  `PARTIAL` recheck record). It named the class before the instance was fully characterised.
- **Two roadmap facts were accurate and timely**: that the roadmap generator's `--regenerate`
  only maintains the coverage appendix, and that `specs/ROADMAP.md` is hand-curated prose not
  mechanically parsed.
- **One correct fact went unused**: that state writes should go through
  `state-write.sh --regen-todo` so the write and TODO regeneration happen together. VERIFIED —
  the flag exists (10 references in that script). A point in Sapience's favour.

**Design consequence**: the most valuable class is the cross-corpus abstraction, which by its
nature belongs to *no single repository*. A filter admitting only items attributed to the current
repo would discard precisely the best part. §9 states this as an acceptance criterion so it is
not rediscovered the hard way.

## 3. Injection sites

VERIFIED present in `~/.claude/settings.json` (extracted via `jq` over `.hooks`):

| Event | Command |
|---|---|
| `SessionStart` | `python3 "$HOME/.sapience/mcp.py" --briefing-text` |
| `UserPromptSubmit` | `python3 "$HOME/.sapience/sapience_cli.py" hook prompt` |
| `PreToolUse` | `python3 "$HOME/.sapience/sapience_cli.py" hook tool` |
| `SessionEnd` | `python3 "$HOME/.sapience/mcp.py" --receipt` |
| `Stop` | `python3 "$HOME/.sapience/mcp.py" --effect-line` |

The first three are the injection paths. All are **vendor-owned** — they invoke scripts under
`~/.sapience/`, which is neither the agent-system source store nor any repo's deploy tree.

VERIFIED: `sapience_cli.py --help` documents only `on [quiet|normal|rich]`, `off`, `level`,
`status`, `visible block|line`, `update [--rollback]`. VERIFIED: a grep for option names matching
`--*(repo|scope|project|filter)*` across both `mcp.py` and `sapience_cli.py` returns **nothing**.
There is no CLI scoping flag.

## 4. Prior art — why this is not a duplicate

The archived task `sapience_per_repo_storage_and_injection` (completed 2026-11-10). REPORTED from
its own summary:

- It added `sapience-retrieve.sh` (repo-filtered `GET /v1/search?source=[repo:<slug>]`) and
  `sapience-remember.sh` (repo-tagged write), and swapped **one** call site — the Stage 3.5
  `memory_context` basename in `orchestrate-build-dispatch.sh`.
- Its Decisions section: per-repo scoping "works only through a literal `[repo:<slug>]` tag in a
  KO's `provenance` string, filtered on read by `source=`; **`project=` and `source_loc` are both
  dead ends on this vault.**" Settled by research, re-confirmed live.
- Its Follow-ups section: "The two-population asymmetry (repo-tagged live writes vs. untagged
  transcript-extraction writes) is documented as a deliberate, unfixed design tradeoff, not a
  defect."
- Its live round trip confirmed the filter works *for tagged KOs*: a matching-filter read found
  the test KO, a non-matching read did not, against a vault of 2163 objects.

That task fixed the agent-system's own **dispatch-prompt** injection and knowingly left the
untagged population unfiltered. The three hooks in §3 were never in its scope — they reach the
**primary session's** context, whereas its scoped path feeds dispatched subagent prompts. This
work is the uncovered-sites and untagged-population remainder, not a regression of it.

The open task `sapience_retrieve_cold_start_retry` concerns retry behaviour, not scoping — but it
shares all three of this task's declared paths (`sapience-retrieve.sh`, that script's `tests/`
directory, and `domain/per-repo-scoping.md`), which is why this task carries a dependency edge on
it rather than running concurrently. The edge orders them; it does not prejudge which lever
research picks.

A grep of the nvim repo's state for "sapience" also surfaced tasks on error logging,
email-preference substrate, file-scope containment, selector aggregation and loader settings —
none about injection scoping.

**Mechanical corroboration of the non-duplicate claim**: `audit-task-proposals.sh`, run over the
full corpus at task-creation time, returned the archived `sapience_per_repo_storage_and_injection`
record as `covered-by-closed` / `mechanical_class: overlap` with **no shared paths** and a
semantic score of 0.354 — below eight unrelated records. The verdict is stored on this task's own
`audit_verdict` field. So the non-duplicate claim rests on the corpus, not only on the argument in
this section.

## 5. Root cause — the headline finding, and it is not what it first looked like

The obvious diagnosis is "the hooks apply no repo filter". **That is wrong, and the code says so.**

VERIFIED by reading `sapience_cli.py`'s hook handler (lines ~440-470):

```
cwd = str(d.get('cwd') or (d.get('workspace') or {}).get('current_dir') or os.getcwd())
if not folder_allowed(cwd): return ''
...
if event == 'session':
    pj = project_of(cwd)
    if not pj: return ''
    body.update(project=pj, since=float(last.get(pj) or 0))
elif event == 'prompt':
    body.update(prompt=p[:2000], project=project_of(cwd))
```

So the client **is already repo-aware and already transmits the current project** on both the
`session` and `prompt` events. It resolves the project from the hook payload's `cwd`, and it
refuses to emit anything at all for a folder outside the configured set (`folder_allowed`).

Set that beside the prior art's settled finding that **`project=` is a dead end on this vault**,
and the two converge on a single root cause:

> **The client asks for repo scoping on every turn. The vault cannot honour the request, because
> the transcript-extracted population carries no repository attribution for `project` to match
> against.**

This unifies what looked like two independent legs into one, and it has a sharp corollary:

- A client-side wrapper that filters vendor stdout **cannot fix this either**, for the same
  reason the server cannot: an item with no repo attribution is unfilterable by anybody
  downstream. A wrapper could only drop items it cannot attribute — which, per §2, is the class
  worth keeping — or guess, which is worse than the current behaviour.
- Therefore **attribution at write/extraction time is the only lever that actually resolves the
  defect**, with everything else being presentation or mitigation. OPEN: whether attribution can
  be added retroactively to the existing population given there is no delete API.

Supporting measurement for the multi-project premise — VERIFIED: `~/.sapience/config.json` has a
`capture.projects` list with **10 entries** and a `folders` list with **5**. One vault holds ten
projects' knowledge by configuration, which is a reasonable thing to want for cross-corpus
abstraction, and is why "stop capturing other projects" is probably the wrong remedy.

## 6. What is NOT established — the research questions

1. **Does the backend accept any scoping parameter that works?** The prior art settled that
   `project=` and `source_loc` are dead ends and `source=[repo:<slug>]` works. But the hook sends
   `project=`. So: is `project=` ignored outright, honoured only for tagged KOs, or honoured but
   defeated by the untagged majority? This distinction decides whether the fix is vendor-side,
   attribution-side, or both.
2. **Can the untagged population be attributed retroactively** — re-extracted or re-ingested with
   `[repo:<slug>]` provenance — given there is **no delete API**? If not, the residual exposure
   must be stated precisely rather than left implicit.
3. **Does extraction know the project at write time?** `extract_local.py` (159 KB) and
   `sapience_capture.py` (33 KB) were not read. If extraction already knows which project a
   transcript came from — and `capture.projects` suggests it must — then attribution at write
   time may be a small change rather than a redesign. **This is the highest-value unread code.**
4. **Suppress, label, or admit-if-general?** An unattributable item is not necessarily noise; the
   most valuable item observed belongs to no repo. A ruling is needed between dropping
   unattributable items, passing them through labelled with their source project, and passing
   them only when they make no repo-specific factual claim. Note that the four false items in §1
   all share a signature — they make **specific factual claims about a named repository artifact**
   (a task number, a phase label, a count, a path) — whereas the valuable items are general. That
   signature may be more tractable than provenance, and is worth evaluating as a discriminator.
5. **Should the framing change?** Independently of filtering, whether items should keep being
   presented as the reader's own prior conclusions is worth ruling on, given §1.

## 7. Candidate levers, re-ranked after §5

| Lever | Confirm by | Kills it |
|---|---|---|
| **Attribution at extraction/write time** (now the leading candidate) | `sapience_capture.py`/`extract_local.py` already know the source project | extraction is project-blind, making this a vendor redesign |
| Vendor/server honouring a scoping parameter | the backend filters correctly once KOs are attributed | depends entirely on the lever above; useless alone |
| Retroactive re-attribution of existing KOs | a re-ingest path exists that tolerates no deletes | no-delete-API makes it unbounded or duplicative |
| Client wrapper filtering vendor stdout | — | **§5: cannot work for unattributed items; can only drop the valuable class or guess** |
| Discriminate on claim shape, not provenance (§6.4) | the "specific claim about a named repo artifact" signature separates the false items from the valuable ones | too brittle or too lossy in practice |
| Owner-side coarse control via `config.json`'s `folders`/`capture.projects` | `folder_allowed()` already gates emission per folder (VERIFIED in code) | too coarse — trades the cross-corpus value away wholesale |
| Narrow/remove the hooks, rely on the already-scoped retrieval path | — | **likely fatal alone**: that path feeds only dispatched subagents, so the primary session would lose Sapience entirely |

## 8. Boundary — what is and is not an agent edit

- **Agent-editable**: the source store at `~/.config/nvim/agent-system/extensions/sapience/`
  (scripts, manifest, context docs). Consumer repos regenerate `.claude/` from it; never
  hand-author under `.claude/**`.
- **OWNER ACTION only, never an agent edit**: `~/.claude/settings.json` (user-scope hook wiring)
  and `~/.sapience/**` (vendor install). Note `mcp.py` **self-updates daily** (`.auto_update.json`
  present, and the CLI documents a daily self-check), so any hand-patch there would be silently
  overwritten — a durable fix cannot live in that tree.
- If the chosen lever lands only in owner-action paths, the deliverable is an exact, runnable
  instruction plus whatever source-store wrapper or documentation makes the arrangement durable
  and discoverable.

## 9. Acceptance criteria proposed for the eventual fix

1. A session in one repository receives no item making a specific factual claim about another
   repository's artifacts — or receives it labelled with its source project, per §6.4's ruling.
2. The cross-corpus abstraction class of §2 is **demonstrably still delivered** after the change.
   A fix that silences the channel is a regression, not a fix. Test this explicitly.
3. Every injection site is covered and enumerated by name — the three hooks of §3, not only the
   dispatch path the prior-art task already handled.
4. The attribution gap of §5 is resolved, or its residual exposure is stated precisely, with the
   no-delete-API constraint acknowledged.
5. Any owner action is written out as an exact, runnable instruction rather than a description,
   and accounts for `mcp.py`'s daily self-update.

## 10. Reproducing every measurement

From `~/Projects/Logos/Verification` unless noted.

```bash
# §1 — do the cited tasks exist? (substitute the numbers from §1)
jq -r '[(.active_projects[]?,.archived_projects[]?)|select(.project_number==435 or .project_number==761)]|length' specs/state.json
ls -d specs/435_* specs/761_* specs/archive/435_* specs/archive/761_* 2>/dev/null

# §1 — phase numbering, topic and task counts
grep -cE 'Phase 1[0-9]' specs/ROADMAP.md
jq -r '"topics=\(.active_topics|length) open=\([.active_projects[]|select(.status!="completed")]|length)"' specs/state.json

# §1 — where the source store actually is
jq -r '[.extensions|to_entries[]|.value.source_dir]|unique|.[]' .claude-extensions.json

# §3 — the injection hooks, and the absence of any scoping flag
jq -r '.hooks|to_entries[]|.key as $e|.value[]?|(.hooks//[])[]?|select((.command//"")|test("sapience"))|"[\($e)] \(.command)"' ~/.claude/settings.json
timeout 25 python3 -I ~/.sapience/sapience_cli.py --help
grep -ohE '\-\-[a-z][a-z0-9-]*(repo|scope|project|filter)[a-z0-9-]*' ~/.sapience/mcp.py ~/.sapience/sapience_cli.py | sort -u   # empty

# §5 — THE KEY ONE: the client already sends the project
grep -nE 'repo_slug|repo:|CLAUDE_PROJECT_DIR|\bcwd\b' ~/.sapience/sapience_cli.py
sed -n '440,470p' ~/.sapience/sapience_cli.py

# §5 — multi-project capture (keys and list lengths only; values withheld deliberately)
python3 -I -c "import json,io; d=json.load(io.open('$HOME/.sapience/config.json')); print({k:(len(v) if isinstance(v,list) else type(v).__name__) for k,v in d.items()})"

# §2 — the --regen-todo flag does exist
grep -c 'regen-todo' ~/.config/nvim/agent-system/extensions/core/scripts/state-write.sh

# §4 — prior art
sed -n '1,80p' ~/.config/nvim/specs/archive/496_sapience_per_repo_storage_and_injection/summaries/01_*-summary.md
```

`~/.sapience/config.json` contains an API token. Print its **keys only**, as above — never its
values.
