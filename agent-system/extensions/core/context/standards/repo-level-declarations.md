# Repo-Level Declarations in `.claude-extensions.json`

## Overview

`.claude-extensions.json`'s top level is open to hand-authored sibling keys beyond the two the
loader itself owns (`extensions`, `version`). This document names the declaration point
generically, documents its survival guarantee, and records the one declaration schema the agent
system currently reads from it: `derived_artifact_probes`, the repo-declared, build-free
derived-artifact staleness probe (see `scripts/lib/derived-artifact-probe-lib.sh` for the reader
and the two call sites that consume it).

## Why `.claude-extensions.json` Survives a Hand-Authored Sibling Key

The loader's Lua read/write path (`lua/neotex/plugins/ai/shared/extensions/state.lua`) round-trips
the whole top-level table on every load/unload/redeploy cycle: `M.read` decodes the file's JSON
into one Lua table and only ensures `state.extensions` exists if it is missing; `M.write`
re-encodes and writes back exactly the table it is given. Neither function strips, allowlists, or
otherwise inspects any key beyond `extensions`/`version`. A sibling key a consumer repo adds by
hand therefore survives every load, unload, and redeploy the loader performs — it is simply never
touched.

This was the deciding reason `.claude-extensions.json` was chosen as the declaration point over
the alternatives considered: `project-overview.md` (free-form prose, not machine-read by any
postflight script) and a per-task `state.json` field (task-scoped, not repo-scoped — a
derived-artifact probe describes the REPOSITORY's own components, not any one task).

## The `derived_artifact_probes` Entry Schema

```json
{
  "derived_artifact_probes": [
    {
      "component": "<name, for logging only -- never interpreted or matched against anything>",
      "check_command": "<a single build-free shell command string>",
      "derived_output_dirs": ["<repo-root-relative directory or file path>", "..."]
    }
  ]
}
```

- `component` — a human-readable label used only in diagnostic output (the `DERIVED-STALENESS:`
  lines both engines emit). Never interpreted, matched, or cross-referenced against anything.
- `check_command` — a single shell command string, run verbatim. It MUST be build-free: a
  read-only check of whether a derived artifact is currently consistent with its inputs, never a
  command that regenerates, writes, or otherwise mutates anything. Exit 0 means "consistent";
  any non-zero exit (including a timeout, reported as 124) means "stale" and refuses the
  dispatch's completion this cycle.
- `derived_output_dirs` — an array of repo-root-relative paths (directories or individual files).
  Any file under one of these prefixes that an implementation agent reports as modified is
  treated as in-scope derived output rather than a `file_scope` excursion, so it is committed
  with the change that caused it instead of being silently dropped (see "Containment and the
  Derived-Output Exemption" below).

## Fail-Open-on-Absence Guarantee

A repo that declares nothing — no `derived_artifact_probes` key at all, this repo included — is
byte-for-byte unaffected by this mechanism: zero probes run, zero prefixes are added to the
containment comparison, and the implement-postflight code path is identical to what it was before
this mechanism existed. The same holds for every other malformed-input case:

| Condition | Result |
|-----------|--------|
| No `.claude-extensions.json` file | `[]` probes, `[]` prefixes, rc 0, nothing executed |
| `jq` unavailable | `[]` probes, `[]` prefixes, rc 0, nothing executed |
| Key absent | `[]` probes, `[]` prefixes, rc 0, nothing executed |
| Key present, empty array | `[]` probes, `[]` prefixes, rc 0, nothing executed |
| One entry missing `check_command`, or `derived_output_dirs` not an array of strings | that one entry is DROPPED, with a named WARNING on stderr; every other valid entry still runs |

This mirrors `scripts/lib/deploy-freshness-lib.sh`'s own "unknown/absent must never read as a
block" contract, applied here to a BLOCKING caller instead of an advisory one — the blocking
behaviour lives entirely in what a declared, VALIDATED `check_command`'s own exit status says,
never in the absence-detection path itself.

## Bounded Execution and Privilege Posture

Each declared `check_command` runs under a single named timeout
(`DERIVED_PROBE_TIMEOUT_SECONDS`, defined once at the top of
`scripts/lib/derived-artifact-probe-lib.sh`), from the repo root, with no privilege or
environment beyond what the implementation agent dispatching this postflight already has. A
declared command is build-free by the repo's own declaration, so this bound is headroom against
incidental slowness (a cold cache, a slow disk), never a budget for a genuinely slow command — a
probe that exceeds it is a loud, named probe FAILURE attributed to the repo's own declaration,
never a silent pass and never an unbounded block. This follows the same bounded-wait discipline
`context/patterns/external-process-wait.md` documents for a long-running external process: a
bounded inner timeout, never an unbounded foreground wait.

## Containment and the Derived-Output Exemption

Independently of the blocking probe, every declared `derived_output_dirs` prefix is spliced into
`orchestrate-cycle-postflight.sh`'s `file_scope`-excursion containment comparison (WORK (h)) at
implement-phase postflight. A regenerated file under one of these prefixes is no longer dropped
as an advisory excursion — it is treated as in-scope derived output and staged with the change
that caused it. This closes the half of the originating incident where a component's gate DID
run and its regenerated certificate WAS reported, but the containment filter dropped it anyway
because it fell outside the task's own declared `file_scope`, leaving `HEAD` internally
inconsistent (a changed `check.sh` committed alongside a stale `digests.txt`). The blocking probe
above closes the OTHER half: a component whose gate never ran at all.

## This Is the System's First *Blocking* Staleness Gate

Every pre-existing drift or staleness check in this codebase is deliberately advisory-only: the
`file_scope` excursion check (detection only, no gate, no exit-code, no verdict effect), the
extension lifecycle hooks (unconditionally non-blocking, with no opt-in blocking mode, and run
AFTER the status write in any case), and `lean-challenge-snapshot.sh --check` (report-only). The
derived-artifact staleness probe documented here is a deliberate, conscious departure from that
convention — it refuses the `implemented`/`completed` transition outright on a non-zero result.

The justification is a measured cost, not a hypothetical one: the motivating incident (an
`/orchestrate` run in a consumer repository) shipped a commit where a changed certificate-identity
input was never regenerated, because only one of two affected components' gates ran. Both the
stale commit and the never-regenerated certificate surfaced only through a manual local CI replay
after the fact; on the remote they would have cost a billed CI run. A blocking gate that catches
this before the status write is cheaper than that.

**This promotion does not extend by analogy.** No other advisory drift check named above —
the `file_scope` excursion advisory, the extension lifecycle hooks, `lean-challenge-snapshot.sh
--check` — is promoted to blocking by this change. Each remains exactly as advisory as it was
before. A future maintainer reading a blocking gate alongside those three advisory ones should
read this as a narrowly-scoped, independently-justified departure, not as the first step of a
general advisory-to-blocking migration.

## See Also

- `scripts/lib/derived-artifact-probe-lib.sh` — the reader and probe-runner this document backs.
- `context/standards/postflight-tool-restrictions.md`'s Exceptions section — the narrowly-scoped
  Bash exception this mechanism's `check_command` invocation requires.
- `docs/guides/creating-extensions.md`'s Lifecycle Hooks section — why a lifecycle hook is the
  wrong vehicle for a repo-level (rather than per-extension) declaration like this one.
