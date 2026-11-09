# Ad-Hoc Navigation Directive (Primary-Session Conversational `--lit`)

## Trigger

The user asks conversationally to consult/search "the literature", a specific paper, or
otherwise invokes `--lit`-like behavior while the primary/root session is **not** inside a
`/orchestrate --lit` dispatch (with `--research`/`--plan`/`--implement`) — i.e. skill Stage 4a did not run for
this request. Without this directive, the primary session has no documented path to reproduce
Stage 4a's literature navigation, so it either fabricates ad-hoc behavior or silently does
nothing. Neither is acceptable.

## Procedure (mirrors Stage 4a, `--orchestrator-mode` hardcoded `false`)

A live user is always present in a conversational request, so the autonomous branch
(`AUTONOMOUS_GLOBAL`) is unreachable here — `--orchestrator-mode` is always passed as `false`.

1. Run the classification helper:

   ```bash
   bash .claude/scripts/literature-lit-flag-resolve.sh --lit-flag true \
     --orchestrator-mode false --query "<user request text>"
   ```

2. Branch on the directive token printed to stdout. Only five of the six directives are
   reachable from the primary session (`AUTONOMOUS_GLOBAL` cannot occur since
   `--orchestrator-mode` is always `false`; `LIT_DISABLED` cannot occur since `--lit-flag` is
   always `true` here):

   - **`SUBINDEX_PRESENT`** → run the per-repo briefing, passing `--query "<user request text>"`
     so the topic-scoped coverage-delta guard can run (see
     `.claude/context/project/literature/domain/sparse-coverage.md`'s "Coverage-Delta Detection"
     section) — without `--query` the guard never runs and the marker's `delta_checked` field
     stays `false`:

     ```bash
     bash .claude/scripts/literature-briefing-invoke.sh --query "<user request text>"
     ```

   - **`GLOBAL_MISSING`** → emit a visible chat notice that no literature is available (no
     per-repo sub-index and no global Literature index found). Do not proceed silently — say so
     in the response, then continue without a briefing.

   - **`PROMPT_NEEDED`** (sub-index absent, global index present) and **`SPARSE_PROMPT_NEEDED`**
     (sub-index present but resolves to fewer than `LITERATURE_SPARSE_THRESHOLD` entries) → issue
     `AskUserQuestion` with the **identical** four options and wording used by the shared Stage
     4a block (see `.claude/context/patterns/lit-stage4a-flow.md`):
     - **"Use global corpus now"** (recommended default, listed first): run
       `literature-briefing-invoke.sh --global "<query>"` and inject the result for this response
       only. No setup, no file writes. If the result's `<!-- lit-coverage ... -->` marker reports
       `sparse=true`, re-prompt with the same four options (two-checkpoint shape) — only when
       this was the option chosen, never after "Skip this run" or "Create curation task".
     - **"Create curation task"**: run `literature-create-setup-task.sh` to create the
       `populate_literature_sub_index` task, then attempt the same Stage 4a-fork inline
       population Stage 4a uses so this conversation also benefits; once
       `specs/literature-index.json` exists (or has more entries), run
       `literature-briefing-invoke.sh --query "<user request text>"`.
     - **"Search online to ingest"**: run `literature-discover.sh "<query>"`, filter candidate
       records to `open_access`/`paywall`/`in_zotero_no_pdf`, ingest each via the STABLE-CONTRACT
       `literature-ingest-online.sh --record` bridge, then re-run the per-repo briefing (with
       `--query "<user request text>"`, same as above) to pick up whatever was ingested. Live
       network calls — this option is always an explicit user choice, never automatic.
     - **"Skip this run"**: an explicit, user-chosen decision. Log `[lit] Skipped by user choice`
       and continue without a briefing — non-silent because it is an explicit, logged choice.

   - `LIT_DISABLED` and `AUTONOMOUS_GLOBAL` are not applicable here: the primary session only
     runs this procedure when the user has requested `--lit`-equivalent behavior (so
     `--lit-flag` is always `true`), and a live user is always present in a conversational
     request (so `--orchestrator-mode` is always `false`).

## Routing the Result

Once a `<literature-briefing>` block has been produced (or the branch above explicitly declined
to produce one), route it one of two ways:

- **(a) Self-execution** — the primary session answers the user's request directly: use the
  briefing content itself, running `literature-search.sh` and `Read`ing chunks on demand per
  `.claude/context/project/literature/patterns/agent-exploration.md`.

- **(b) Subagent dispatch** — the primary session is about to delegate to a subagent (e.g. via
  the `Agent` tool): inject the `<literature-briefing>` block into the subagent's prompt using
  the same placement rule every lifecycle skill's dispatch Stage 5 uses — after `<memory-context>` (if any) and
  before task-specific instructions.

Never dispatch an empty `<literature-briefing>` block. If no briefing was produced (the
`GLOBAL_MISSING` or "Skip this run" branches), inject nothing rather than an empty tag.

## Non-Silence Invariant

No branch above may silently inject nothing or silently auto-search. Every branch either:
produces a `<literature-briefing>` block, or explicitly and visibly announces why none was
produced (a logged notice or an explicit user choice). This mirrors the non-silence invariant
that governs Stage 4a itself.

## Sources of Truth

This file documents primary-session-specific *routing* (self-execution vs. subagent dispatch)
around the existing directive machinery — it does not re-derive the classification rules. For
the canonical classification logic and exact `AskUserQuestion` wording, see:

- `.claude/context/patterns/lit-stage4a-flow.md` — the single shared Stage 4a block all six
  `--lit` skills import: the directive branching, the four-option `AskUserQuestion` (shared by
  `PROMPT_NEEDED` and `SPARSE_PROMPT_NEEDED`, including "Search online to ingest"), the
  two-checkpoint sparse re-prompt, the Stage 4a-fork inline population procedure, the autonomous
  `[lit:auto]` fallback, and the injection-placement rule.
- `.claude/scripts/literature-lit-flag-resolve.sh` — the single source of truth for directive
  classification (six directives, including `SPARSE_PROMPT_NEEDED`).
- `.claude/scripts/literature-briefing.sh` — the source of the `<!-- lit-coverage ... -->`
  machine-readable marker and `[SPARSE COVERAGE ...]` banner used by the two-checkpoint re-prompt.

If Stage 4a's wording or branching changes, update this file to match rather than letting the
two drift apart.
