# Research Report: CWD-relative hook registration paths cause blocking guards to fail open

- **Task**: 364 - Resolve hook registration paths independently of session CWD so bare-registered blocking guards cannot fail open
- **Started**: 2026-10-07T12:00:00Z
- **Completed**: 2026-10-07T12:00:00Z
- **Effort**: Pre-research evidence capture (under 1 hour)
- **Dependencies**: None
- **Sources/Inputs**:
  - Live session transcript, `sess_1791385200_b7e3f1` (harness `PreToolUse:Bash hook error` output)
  - `/home/benjamin/Philosophy/Papers/PossibleWorlds/.claude/settings.json` (deployed artifact)
  - `/home/benjamin/.config/nvim/agent-system/extensions/core/root-files/settings.json`
  - `/home/benjamin/.config/nvim/agent-system/extensions/core/merge-sources/settings-hooks.json`
  - `/home/benjamin/.config/nvim/agent-system/extensions/core/root-files/settings.local.json`
  - `/home/benjamin/.config/nvim/agent-system/extensions/email/settings-fragment.json`
  - `/home/benjamin/.config/nvim/agent-system/extensions/books/settings-hooks.json`
  - `/home/benjamin/.config/nvim/specs/state.json`, `/home/benjamin/.config/nvim/specs/TODO.md`
  - `env` output of the Bash tool in the reporting session
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## STATUS OF THIS DOCUMENT

**This is a PRE-RESEARCH EVIDENCE CAPTURE written by the reporting session, not a completed
research report.** It records primary evidence observed while the defect was reproducing live, so
that evidence is not lost before `/research 364` runs. It deliberately does NOT settle the
mechanism question (see `## The Open CLAUDE_PROJECT_DIR Question`); the research phase owns that.
Every figure below was measured in this authoring session against the files and session named in
Sources/Inputs -- there are no carried figures.

## Executive Summary

- Every hook registration in the agent-system source store invokes its script as
  `bash .claude/hooks/<name>.sh` -- a path resolved against the **session CWD**, not the project
  root.
- Bash-tool CWD persists across tool calls within a session. One `cd` into a subdirectory
  therefore disables every registered hook for the remainder of the session.
- A missing script makes `bash` exit **127**. The harness classes a nonzero hook exit other than
  2 as a **non-blocking** failure, prints a warning, and proceeds. So the hook **fails open**.
- This specifically defeats the **six bare-registered blocking guards**, which are registered
  without the `2>/dev/null || echo '{}'` suffix precisely so their `exit 2` reaches the harness
  and blocks the tool call. When the script cannot be found, there is no `exit 2` to deliver.
- Observed live in session `sess_1791385200_b7e3f1`: both git guards were inert while the session
  CWD sat in a subdirectory, and the warnings stopped the instant CWD returned to the repo root.
- The deployed consumer `.claude/settings.json` carries **21** `bash .claude/hooks/`
  registrations and **0** occurrences of `CLAUDE_PROJECT_DIR`.
- The intended fix mechanism is **not yet determined**: `CLAUDE_PROJECT_DIR` is absent from the
  Bash tool's environment and absent from the entire agent-system, so whether the harness exports
  it to *hook* commands is an open empirical question that gates the choice of remedy.

## Context & Scope

In scope: the **registration surface** -- the `command` strings inside `hooks` blocks of every
settings file in the source store, plus (conditionally) the CWD-relative permission matchers in
`settings.local.json`.

Out of scope: script-internal path resolution. The hook scripts themselves already resolve their
own libraries via `BASH_SOURCE`, which is CWD-independent and correct. The defect is entirely in
how the harness is told to find the script in the first place.

Also out of scope: task 303 (`validate_state_cwd_relative_default_resolution`), a script-internal
default-argument bug. `specs/TODO.md` line 2823 already records the two as "unrelated beyond both
being path-resolution bugs."

## Findings

### F1. Live reproduction (primary evidence)

Session `sess_1791385200_b7e3f1`, consumer repo
`/home/benjamin/Philosophy/Papers/PossibleWorlds`.

The session's first Bash tool call ran:

```
cd /home/benjamin/Philosophy/Papers/PossibleWorlds/JPL && ...
```

Bash-tool CWD persists across calls, so the session CWD moved into `JPL/`, where no `.claude/`
directory exists. Every subsequent Bash tool call then emitted, verbatim:

```
PreToolUse:Bash hook error
Failed with non-blocking status code: bash: .claude/hooks/guard-destructive-git.sh: No such file or directory
PreToolUse:Bash hook error
Failed with non-blocking status code: bash: .claude/hooks/guard-git-push.sh: No such file or directory
```

Both git guards were inert for the duration. The errors stopped the moment CWD returned to the
repo root. Note the harness's own wording in that message: **"non-blocking status code"**. The
harness is reporting, in the failure message itself, that the guard did not block.

### F2. The fail-open mechanism

The chain is mechanical and has no discretionary step:

1. The hook command is `bash .claude/hooks/guard-git-push.sh` with no absolute anchor.
2. `bash` cannot find the script relative to the session CWD and exits **127**.
3. The harness treats a nonzero hook exit **other than 2** as a non-blocking failure: it prints
   the warning above and allows the tool call to proceed.
4. A guard registered bare *specifically so that `exit 2` blocks* therefore becomes a **no-op**.

The failure mode is maximally adverse: the guard is silent about the thing it guards and loud
only about its own absence, in a warning that is easy to read as cosmetic noise.

### F3. Affected source-store surfaces

All paths relative to `/home/benjamin/.config/nvim/agent-system/extensions/`. Line numbers
measured in this session.

| File | Bare (blocking) registrations | Other affected lines |
|---|---|---|
| `core/root-files/settings.json` | 51 `guard-destructive-git.sh`, 60 `validate-no-task-references.sh`, 69 `guard-git-push.sh`, 164 `please-grant.sh` | 80 (nested, see F4), 89, 93, 104, 113, 128, 132, 136, 140, 151, 155, 175, 180, 191 -- all advisory, all CWD-relative |
| `core/merge-sources/settings-hooks.json` | 7 `validate-no-task-references.sh`, 13 `guard-destructive-git.sh`, 19 `guard-git-push.sh`, 59 `please-grant.sh`, 67 `validate-handoff-location.sh` | 27, 35, 36, 44, 52, 53, 68, 69, 75 -- advisory, CWD-relative |
| `books/settings-hooks.json` | 7 `validate-evidence-append-only.sh` | -- |
| `email/settings-fragment.json` | none | 7 `mail-guard.sh` -- advisory (carries `\|\| echo '{}'`), shares the path defect |
| `core/root-files/settings.local.json` | n/a (permission matchers, not hooks) | 15, 16, 18, 19, 43, 45 -- `Bash(bash .claude/scripts/...)` matchers; see F6 |

The **six distinct bare-registered blocking guards** across those surfaces:

1. `guard-git-push.sh`
2. `guard-destructive-git.sh`
3. `validate-no-task-references.sh`
4. `please-grant.sh`
5. `validate-handoff-location.sh`
6. `validate-evidence-append-only.sh`

Note that the defect spread into **extension-provided** settings surfaces (`email`, `books`), not
just core. Any remedy -- and any lint guarding the remedy -- must cover extension surfaces.

### F4. A second syntactic shape that a naive fix pass will miss

`core/root-files/settings.json` line 80 nests a CWD-relative hook path **inside a `bash -c`
wrapper**:

```
"command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"specs/state.json\"* ]]; then bash .claude/hooks/validate-state-sync.sh 2>/dev/null || echo \"{}\"; else echo \"{}\"; fi'"
```

A fix (or a lint) that only matches registrations whose `command` *begins* with
`bash .claude/hooks/` will skip this one. Both shapes must be handled.

### F5. Deployed-artifact counts

Measured against `/home/benjamin/Philosophy/Papers/PossibleWorlds/.claude/settings.json`:

- Lines matching `bash \.claude/hooks/`: **21**
- Occurrences of `CLAUDE_PROJECT_DIR`: **0**

### F6. The `settings.local.json` permission matchers (scope question, deliberately unresolved)

`core/root-files/settings.local.json` carries CWD-relative **permission** matchers:

- line 15: `"Bash(bash .claude/scripts/check-extension-docs.sh)"`
- line 16: `"Bash(bash .claude/scripts/check-extension-docs.sh --quiet)"`
- line 18: `"Bash(bash .claude/scripts/check-task-references.sh)"`
- line 19: `"Bash(bash .claude/scripts/check-task-references.sh --quiet)"`
- line 43: `"Bash(bash .claude/scripts/update-task-status.sh postflight ...)"`
- line 45: `"Bash(bash .claude/scripts/update-task-status.sh preflight ...)"`

A permission matcher matches the **literal command text** a tool call presents, whereas a hook
command is **executed**. These are different mechanisms, and whether the matchers are
CWD-sensitive in the same way is **not established here**. Per the user-confirmed scope decision:
investigate, and include them in this task **only if they share the defect**. Do not assume
either way.

### F7. No existing open task covers this

Verified against `/home/benjamin/.config/nvim/specs/state.json` and `specs/TODO.md`:

- Task **303** (`validate_state_cwd_relative_default_resolution`, not_started) -- script-internal
  default-argument bug, not the registration surface. `TODO.md` line 2823 already records the two
  as unrelated.
- Tasks **282** (`record_versioning_write_time_hook`, not_started) and **347**
  (`self_match_waiter_pretooluse_block_hook`, not_started) **ADD** registrations to
  `core/merge-sources/settings-hooks.json` rather than fixing the path shape. Neither can be
  naturally extended to cover this.

### F8. Two open tasks will inherit the defect verbatim

Tasks 282 and 347 both add new hook registrations to
`core/merge-sources/settings-hooks.json`, and both will copy the surrounding CWD-relative style.
Task 347's own title states that it registers bare **"so exit 2 survives"** -- the exact property
this defect destroys. Task 282's description likewise mandates bare registration, warning that
the `|| echo '{}'` wrapper "converts exit 2 into exit 0 and silently disables" the hook; the
CWD-relative path achieves the same disabling by a different route that 282's text does not
anticipate.

Sequencing consideration: whichever of {364, 282, 347} lands second must adopt the fixed path
shape.

## The Open CLAUDE_PROJECT_DIR Question

**This is the gating question and it is NOT answered here.** The research phase must settle it
empirically before any remedy is chosen.

Evidence gathered so far, all measured in this session:

- `CLAUDE_PROJECT_DIR` appears **nowhere** in the agent-system: a grep across all extensions
  returns zero hits.
- `CLAUDE_PROJECT_DIR` is **absent** from the Bash tool's own environment. The reporting
  session's `env | grep -i claude` returned `CLAUDE_CODE_CHILD_SESSION`,
  `CLAUDE_CODE_SESSION_ID`, `CLAUDE_PID`, `CLAUDE_EFFORT`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS`,
  `CLAUDE_CODE_FORK_SUBAGENT`, `CLAUDE_CODE_MESSAGING_SOCKET`, `CLAUDECODE`,
  `CLAUDE_CODE_SESSION_ATTENDED`, `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION`,
  `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, `CLAUDE_CODE_ENTRYPOINT`, `CLAUDE_JOB_DIR`,
  `CLAUDE_CODE_EXECPATH`, `CLAUDE_CODE_MESSAGING_TOKEN` -- and no `CLAUDE_PROJECT_DIR`.
- **Crucially, this does not settle the question.** Hook commands are spawned by the harness
  through a different path than Bash tool calls and may receive a different environment. The
  Bash-tool observation is suggestive, not dispositive.

**Required experiment**: register a throwaway hook that dumps its own environment, trigger it, and
read what it actually received. Verify by direct experiment, not by documentation alone.

## Decisions

- D1. Record this as its own task rather than folding it into 282, 347, or 303. None of those
  owns the registration surface (F7).
- D2. Do **not** pre-commit to a remedy. The mechanism is left open for research to settle, gated
  on the `CLAUDE_PROJECT_DIR` question.
- D3. Treat 282 and 347 as **recorded** external dependencies, not blocking edges. They do not
  block this fix; they are sequencing hazards if this fix lands second.
- D4. Leave the `settings.local.json` permission matchers in `file_scope` as **conditional**,
  resolved by the F6 investigation.

## Recommendations

Prioritized, for `/research 364` and the plan that follows:

1. **Answer the gating question first** (F6/`## The Open CLAUDE_PROJECT_DIR Question`). Every
   downstream choice depends on it. Experiment, do not read documentation and infer.
2. **If `CLAUDE_PROJECT_DIR` is exported to hooks**: adopt
   `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/x.sh`. Confirm the quoting survives JSON escaping,
   and confirm `deep_merge` dedup still matches entries across `root-files/settings.json` and
   `merge-sources/settings-hooks.json` -- the two files carry overlapping registrations that must
   continue to dedupe after the string changes.
3. **If it is not reliably available**, evaluate the two fallbacks on their stated trade-offs:
   (a) deploy-time absolute-path substitution by the `<leader>al` loader -- harness-independent,
   but bakes machine-specific paths into a generated artifact; (b) a single self-locating
   dispatcher resolving the root via `git rev-parse --show-toplevel` and exec'ing the named hook
   -- one indirection point, but adds a process per invocation and a new failure mode outside a
   git repo.
4. **Handle both syntactic shapes** (F4), including the `bash -c`-nested path at
   `core/root-files/settings.json` line 80.
5. **Cover extension surfaces** (F3), not just core -- `email` and `books` are where the defect
   already spread.
6. **Verify in the deployed artifact, by reproduction.** Deploy into a consumer repo, grep the
   resulting `.claude/settings.json`, then reproduce the original failure (cd into a
   subdirectory, make a Bash tool call) and confirm the guards now fire. The house convention of
   verifying registration bare-ness in the DEPLOYED artifact applies here too.
7. **Preserve the bare-vs-`|| echo '{}'` distinction exactly** (F3). The six blocking guards stay
   bare so `exit 2` still blocks; advisory hooks keep their fail-open suffix. A remedy that
   normalizes all registrations to one shape would trade this defect for the one task 282 and 347
   are each separately guarding against.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| A remedy that changes command strings breaks `deep_merge` dedup between `root-files/settings.json` and `merge-sources/settings-hooks.json`, producing duplicate hook invocations | Verify dedup explicitly after the string change (Recommendation 2); assert registration counts in the deployed artifact |
| Fix pass misses the `bash -c`-nested shape, leaving one silent fail-open path | F4 names the exact line; the companion lint task must match both shapes |
| Deploy-time absolute substitution (fallback a) bakes a machine path into a committed-looking artifact, breaking on another machine or in CI | Confirm `.claude/` is gitignored in consumer repos before accepting this fallback |
| Dispatcher fallback (b) fails outside a git repo, where `git rev-parse` returns nonzero | Any dispatcher must fail **loudly** there, not fall back to a CWD-relative path -- that would reintroduce this exact defect |
| 282 or 347 lands after the fix and reintroduces the defect by copying surrounding style | The companion verify-deploy gate task (365) exists specifically for this; it is the durable mitigation |

## Appendix

### A1. Commands used to measure the figures in this report

```
# F3 -- affected surfaces and line numbers
grep -n 'bash \.claude/hooks/' core/root-files/settings.json
grep -n 'bash \.claude/hooks/' core/merge-sources/settings-hooks.json
grep -n 'bash \.claude/hooks/' email/settings-fragment.json
grep -n 'bash \.claude/hooks/' books/settings-hooks.json

# F6 -- permission matchers
grep -n 'bash \.claude/' core/root-files/settings.local.json

# F5 -- deployed artifact counts
grep -c 'bash \.claude/hooks/' .claude/settings.json      # 21
grep -c 'CLAUDE_PROJECT_DIR' .claude/settings.json        # 0

# Open question -- Bash tool environment
env | grep -i claude
```

### A2. Related task records

- 282 `record_versioning_write_time_hook` (not_started) -- adds a bare PreToolUse Write|Edit hook
- 347 `self_match_waiter_pretooluse_block_hook` (not_started) -- adds a bare PreToolUse Bash hook
- 303 `validate_state_cwd_relative_default_resolution` (not_started) -- unrelated, script-internal
- 318 `wire_directory_pathspec_lint_as_verify_deploy_gate` (not_started) -- house-pattern precedent
  for pairing a defect fix with a verify-deploy gate
