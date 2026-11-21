# Transcript-Filter Ceiling

## What `source_skip()` Does

`~/.sapience/upload.py`'s `source_skip()` is the gate the transcript-extraction path
(`sapience sync` / `coverage` / `pending` / `review`) runs before reading any session transcript
under `~/.claude/projects/`. For each transcript it returns one of three verdicts: `''` (read
it), `'subagent'`, or `'harness-started'`. The classification logic itself lives in
`sapience_filter.py`'s `source_rule()`:

- **`subagent`** -- the transcript's path contains a `subagents/` segment, or its filename
  starts with `agent-`. This is a pure path-based rule.
- **`harness-started`** -- determined by `harness_started()`, which reads the transcript's
  opening substantive human turns (`HARNESS_TURNS = 8`): if all of the first eight are
  harness/cross-session messages rather than a person typing, the session is classified
  `harness-started`.

Both verdicts are final once computed, and `source_skip()` caches them in
`~/.sapience/source_rules.json` keyed by file path and size, so the classification is not
re-evaluated on every poll.

## Not Overridable by an Environment Variable

`upload.py` states explicitly, in its own skip message, that `SAPIENCE_INCLUDE_HEADLESS=1` does
NOT override the `harness-started` classification: "skipped (thread mechanics, not knowledge;
SAPIENCE_INCLUDE_HEADLESS=1 does not override this)". That environment variable has a real
effect elsewhere (`extract_local.py`'s `--include-agents` flag), but not on this gate.

## The Practical Consequence for Orchestrated Work

Most work in this repository runs through `/orchestrate`-dispatched sessions: a root session
that starts from cross-session/harness messages rather than a person typing, plus every
subagent transcript nested under it. Both shapes are exactly what `source_skip()` is designed to
filter. On this machine, a measured census found 1013 of 1295 transcripts on disk removed by
this filter, against 203 eligible -- a ratio consistent with "most sessions on this machine are
orchestrated, not interactive," not an anomaly or a misconfiguration.

**Conclusion**: orchestrated or subagent work cannot reach the hosted vault through the
transcript-extraction path at all, by design, regardless of environment variables. The surviving
path for this kind of work is this extension's own direct `POST /ingest-kos` call
(`scripts/sapience-remember.sh`, called from the postflight wrapup instruction) -- not an MCP
tool call; see `review-gate-boundary.md`'s `## Write-Tool Disposition` section for why none of
the four MCP write tools is named as the write path. This is the direct motivation for this
extension's gap-2 instruction: a documentation-only postflight call is not a workaround for a
missing feature, it is the only mechanism that can function at all for orchestrated dispatches.

## Ruling 4: Link State Does Not Loosen This Filter

A repo carrying `.sapience/project.json` gets no exemption from `source_skip()`:
`subagent`/`harness-started` classification is a fixed, non-overridable gate independent of
project linkage, and the premise that the postflight pass makes the filter redundant does not
hold either. Postflight writes a bounded, curated 3-8-note set the completing agent itself
selected as noteworthy -- a different object from the full raw transcript, not a superset of it.
Admitting the full orchestrated transcript into extraction alongside that curated set would
reintroduce exactly the unbounded, unreviewed, un-curated volume this filter and the write-path
bound both exist to prevent. See
`context/project/sapience/domain/linked-repo-write-policy.md`'s Ruling 4 for the full
cross-harness statement of this ruling.

**Check**: a linked repo's session transcripts classify `subagent`/`harness-started` in
`~/.sapience/source_rules.json` exactly as an unlinked repo's do -- linking changes no verdict.
