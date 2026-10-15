# Phase 2: Per-Gate `input_corpus` Declaration Notes

For each of the 23 gates, what `gateN_run`'s own body in `verify-deploy.sh` actually reads
(established by reading the function, not by its description), the declared `input_corpus`
entry, and what was considered and excluded. Risk calibration: a gate whose `cost_class` is
`free` and whose exact read set I could not pin down with full confidence (gate 14) is declared
`-` (never skippable) rather than guessed — skipping it saves almost nothing (it is already
near-free), so the safe default costs nothing, while an under-declared corpus on a real gate
risks the "silent false pass" the dispatch forbids. Gates whose cost class makes skip-caching
actually matter (3, 4, 6, 8, 10, 12, 17, 21, 22, 23 and others) got a confident, evidence-read
declaration instead.

| Gate | Reads (from the function body) | Declared `input_corpus` | Considered and excluded |
|---|---|---|---|
| 1 | Existence of 9 specific deployed files under `.claude/{scripts,hooks,context}` | explicit 9-path list, each exactly as checked | A directory-level `.claude/scripts`/`.claude/hooks`/`.claude/context` declaration was considered and rejected as over-broad: the gate checks exactly these 9 paths, nothing else under those directories affects its verdict. |
| 2 | `.claude/settings.json` only (via `jq`) | `.claude/settings.json` | N/A — single file, unambiguous. |
| 3 | `check-extension-docs.sh` over the whole source-store extensions tree, PLUS (under `STRICT_CORE_DEPLOY=1`) a diff against the deployed tree for undeployed event files | `@extensions,.claude` | A narrower glob (e.g. just `manifest.json` files) was considered and rejected: the 1,707-line script's exact per-rule read set was not independently re-derived in this phase (Phase 11 is the dedicated attribution phase for gate 3), so the broad-but-safe superset is used rather than guessing a narrower one that risks missing a real read. |
| 4 | `check-task-references.sh --quiet`: `git ls-files` repo-wide, minus `specs/**` (per that script's own documented scope, confirmed in the gate's own header comment) | `@repo,!specs/**` | A per-extension declaration was considered and rejected: the lint is explicitly repo-wide by design, so declaring only `@extensions` would under-declare and risk missing a real citation outside that subtree. |
| 5 | `manager.verify_all` — declared-vs-deployed manifest parity and content-hash equality across every `provides.*` category, i.e. both the source-store declarations and the deployed tree | `@extensions,.claude` | Same reasoning as gate 13 (its mirror in the opposite direction): the comparison genuinely reads both sides. |
| 6 | `lint-agent-contracts.sh --verbose` over the source-store extensions tree | `@extensions` | N/A — confirmed source-store-only scope from the gate's own `[SKIP]` guard precedent comment. |
| 7 | `lint-routing-wiring.sh --verbose` over the source-store extensions tree | `@extensions` | N/A — same precedent as gate 6. |
| 8 | `tests/run-all.sh` over the full discovered suite pool, which collectively exercises nearly the entire `agent-system/extensions` tree | `@extensions` | A narrower declaration (e.g. only `scripts/tests/**`) was considered and rejected: the suites import and exercise libraries and scripts across the whole tree, so a change anywhere under `agent-system/extensions` can change `run-all.sh`'s result. This is the single most consequential corpus declaration in the registry (gate 8 is 62% of a full sweep), so the deliberately broad, safe superset is used rather than a precise-but-risky narrower one. |
| 9 | `lint-postflight-boundary.sh --verbose` against the DEPLOYED tree, default scan targets `$PROJECT_ROOT/.claude/skills` and `$PROJECT_ROOT/.claude/extensions` (per the gate's own header comment) | `.claude/skills,.claude/extensions` | N/A — read directly from the gate's own documented default scan targets. |
| 10 | `validate-state.sh --deep specs/state.json`, which also shells out to `generate-todo.sh` for its TODO.md-sync sub-check | `specs/state.json,specs/TODO.md` | A whole-`specs/` declaration was considered and rejected as over-broad: this gate validates exactly these two files' mutual consistency, not the rest of the task-management tree. |
| 11 | `lint-contract-compliance.sh --verbose` over the source-store extensions tree | `@extensions` | N/A — same source-store-only precedent as gates 6/7. |
| 12 | `lint-state-writer-boundary.sh --verbose` over the source-store extensions tree | `@extensions` | N/A — same precedent. |
| 13 | `manager.find_orphans` — the reverse direction from gate 5 (deployed -> declared); reads both the deployed tree and the source-store declarations | `@extensions,.claude` | Same reasoning as gate 5. |
| 14 | `check-runtime-file-tracking.sh`'s three checks (ignore coverage, no tracked ephemeral file, provenance not over-ignored) against `.gitignore` and `specs/000_probe/...`-style probe paths | `-` (not declared) | A `.gitignore`-only declaration was considered, but the "no tracked ephemeral file" check's exact read set (which appears to be a function of the whole repo's tracked-file index, not a fixed path list) was not independently re-derived with full confidence in this phase. `free` cost class means skip-caching this gate buys negligible time, so the safe `-` placeholder is used rather than risking an under-declaration on a gate not worth the risk. |
| 15 | `lint-lifecycle-status-var.sh --verbose`; the gate's OWN header comment states its default scan corpus explicitly: `agent-system/extensions/*/skills/*/SKILL.md` and `agent-system/extensions/*/context/patterns/*` | `agent-system/extensions/*/skills/*/SKILL.md,agent-system/extensions/*/context/patterns/*` | N/A — read verbatim from the gate's own documented scan corpus, the most precisely self-documented of the 23. |
| 16 | Loops `"$CLAUDE_DIR"/extensions/*/manifest.json` reading each for `routing_hard`/`routing_agents_hard` keys | `.claude/extensions/*/manifest.json` | N/A — read directly from the gate's own `for` loop glob. Declared despite being a known-pre-existing-warning gate (per the dispatch, the WARNING itself is out of scope; declaring its corpus is not). |
| 17 | `lint-scoped-commit-boundary.sh --verbose` over the source-store extensions tree | `@extensions` | N/A — same source-store-only precedent. |
| 18 | `lint-task-lookup-adoption.sh --verbose` over the source-store extensions tree | `@extensions` | N/A — same precedent. |
| 19 | `lint-branch-gated-sections.sh --verbose` over the source-store extensions tree | `@extensions` | N/A — same precedent. |
| 20 | `measure-eager-context.sh --check` (documented as "predict from source store, never read the deploy tree") plus `orchestrator-context-budget.json` and each of its `.files` keys, all resolved under `agent-system/extensions/core/` | `@extensions` | A literal enumeration of just the budget config plus its current `.files` keys was considered and rejected: `@extensions` already supersets it (the config and every ceiling-checked file live under that subtree) and stays correct if the config's file list changes later, which a literal list would not. |
| 21 | `lint-hook-registration-paths.sh --verbose` over the source-store extensions tree | `@extensions` | N/A — same precedent as gates 6/7/11/12/17/18/19. |
| 22 | `lint-shellcheck.sh --verbose`; per the dispatch's own background, this is the one lint using `git ls-files` repo-wide (not extensions-scoped) | `**/*.sh` | An `@extensions` declaration was considered and rejected as under-declaring: shellcheck's own corpus is explicitly repo-wide (every tracked `.sh` file), not extensions-scoped, confirmed by the dispatch's own disproved-premise note ("only lint-shellcheck.sh uses git ls-files"). |
| 23 | `lint-directory-pathspec-boundary.sh --verbose`; the gate's own comment states its default scan root IS `$PROJECT_ROOT/agent-system/extensions` | `@extensions` | N/A — read directly from the gate's own documented default scan root. |

## Grammar notes carried from this declaration pass

- `@extensions` and `@repo` are the two named views defined in `gate-registry.data`'s own
  `input_corpus` field-header comment: `@extensions` reuses the EXISTING
  `gate_registry_shared_corpus_build` producer (Phase 9 of the framework task) rather than
  re-walking; `@repo` is a new, not-yet-implemented view this phase's grammar reserves for
  gates 4 and 22, which are genuinely repo-wide rather than extensions-scoped.
- The `!`-prefixed exclusion shape (`@repo,!specs/**`) was added to the grammar specifically to
  express gate 4's scope precisely (repo-wide minus `specs/**`) without inventing a third named
  view just for that one subtraction.
- Resolving these grammar shapes into an actual path list is explicitly OUT OF SCOPE for this
  phase (Phase 2's own task list: "Confirm no behavioural change: the field is loaded and
  queryable and nothing reads it yet") — that is Phase 3's job (the content-addressed digest
  library). This phase only needed the grammar to be well-DEFINED and LINT-ENFORCEABLE, which
  `lint-gate-registry.sh`'s new Check G now is.
