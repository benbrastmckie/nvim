# Errors.json Record Disposition Audit

- **Task**: 591 - Decide the fate of the errors.json triage surface
- **Type**: audit report (Phase 1 deliverable)
- **Standards**: report-format.md

## Verdict

`specs/errors.json` and its triage surface (`scripts/errors-append.sh`, the `/errors` command)
are retired outright. The capability comparison in the implementation plan's Decision Record
holds on direct re-check:

- `errors-append.sh append` (the write path) has zero production call sites; the only live
  caller of the script is `commands/errors.md`, and it calls `update` only.
- Every record's `fix_status` is either `fixed` or `unfixed` — grepping the full git history of
  `specs/errors.json` finds **zero** occurrences of `fix_status: "in_progress"`, and no commit
  message anywhere in history mentions running `/errors --fix` or
  `errors-append.sh update`. The 9 records marked `fixed` were closed by direct edits to
  `specs/errors.json` from within the discharging task's own dispatch (confirmed below for each
  one), never by driving the `/errors --fix` lifecycle itself. The "mutable `fix_status` living
  record" capability the plan's Decision Record flagged as unexercised is empirically
  unexercised: nothing ever advanced a record through it.
- Cross-task grouping, severity/classification vocabulary, cross-repo durability, and
  three-channel promotion are all already provided by `issues.jsonl` plus the orchestration
  conclusion stage, as the plan's Decision Record states.

## Per-Record Disposition

All 19 records dumped from `specs/errors.json` at audit time (`jq -r '.errors[] | "\(.id)\t...\"'`
— count matches the plan's Scope Hypothesis exactly: 19 records, 10 `unfixed`, 9 `fixed`).

| id | type | fix_status | fix_task | Discharging task / disposition |
|---|---|---|---|---|
| `err_1786344051474_RcIhk6` | delegation_interrupted | unfixed | none | Task 995 (named in the message) was later completed: `git log` shows `task 995: complete implementation` (commits `bd6ef29ed`, `becb8b71d`) after this incident. Resumed and finished by a later dispatch; no separate fix task. |
| `err_1786349061492_XpY38x` | hook_regex_defect | fixed | 47 | `specs/archive/047_clear_failing_gates_and_reconcile_ledgers` — confirmed discharging task. |
| `err_1786349061524_pY97cE` | lock_session_self_contention | fixed | 47 | `specs/archive/047_clear_failing_gates_and_reconcile_ledgers` — confirmed discharging task. |
| `err_1786349061556_LuKGif` | deploy_ghost_index_entries | fixed | 9 | `specs/archive/009_resolve_deploy_orphan_file_parity` — confirmed discharging task. |
| `err_1786349061588_fqHbUZ` | defect_vocabulary_gap | unfixed | none | `specs/archive/011_expand_defect_class_vocabulary` — title and scope match directly; record's `fix_status` was never advanced even though the underlying gap was closed. |
| `err_1786350581208_23mAsn` | deploy_merge_content_loss | fixed | 1015 | Task 1015 (`specs/1015_recheck_settings_local_merge_content_loss` at the time) closed this record directly: commit `480027cad` ("task 1015 phase 1: close the content-loss error record via the sanctioned writer") shows a 4-line diff to `specs/errors.json` itself, and `429a11451`/`09cfb0793` ("task 1015: complete implementation") land the full re-check. The task directory no longer exists under the current numbering/archive (pruned by a later vault renumbering pass) but the commits are reachable in history. |
| `err_1786350581240_JyztWt` | deploy_nondeterministic_merge | fixed | 50 | `specs/archive/050_restore_verification_trust_and_close_hygiene_residue` — confirmed discharging task. |
| `err_1786350581273_TAWj0I` | deploy_orphan_files_undercounted | fixed | 9 | `specs/archive/009_resolve_deploy_orphan_file_parity` — confirmed discharging task (same task closes both this and the `deploy_ghost_index_entries` record above, which the record text itself says it extends). |
| `err_1786350581305_8cNAZ7` | test_suite_failure_undocumented | fixed | 47 | `specs/archive/047_clear_failing_gates_and_reconcile_ledgers` — confirmed discharging task. |
| `err_1786350581339_Q4VnFy` | acceptance_criterion_not_instrumented | unfixed | none | `specs/archive/013_instrument_gate_out_auto_repair_reporting` — title and scope (instrumenting gate-out auto-repair reporting) match directly; `fix_status` never advanced. |
| `err_1786368358319_8jwcdo` | test_suite_deployed_mode_failures | fixed | 47 | `specs/archive/047_clear_failing_gates_and_reconcile_ledgers` — confirmed discharging task (the gate/suite reconciliation task covers the deployed-mode suite failures named here). |
| `err_1787019509935_soHgFv` | delegation_interrupted | unfixed | none | Task 17 (named in the message) was later completed: `git log` shows `task 17: complete implementation` (`c604cb41b`, `1de9e575c`). Resumed and finished by a later dispatch. |
| `err_1787019509995_JTRNOp` | delegation_interrupted | unfixed | none | Task 18 (named in the message) was later completed: `git log` shows `task 18: complete implementation` (`2a468f6fe`, `6b6307eaf`). Resumed and finished by a later dispatch. |
| `err_1787019510054_i344K4` | delegation_interrupted | unfixed | none | Task 65 (named in the message) was later completed: `git log` shows `task 65: complete implementation` (`3e8e4d05d`) and `task 65: complete orchestration` (`4c2ff8727`). Resumed and finished by a later dispatch. |
| `err_1787021593485_Bd0KIX` | index_entries_line_count_stale | unfixed | none | `specs/archive/047_clear_failing_gates_and_reconcile_ledgers` — its own report and summary directly name correcting the same 3 `line_count` mismatches this record describes (`skill-postflight-flow.md`, `file-metadata-exchange.md`, `postflight-tool-restrictions.md`), confirmed by grep against the archived summary/report. `fix_status` was never advanced even though the underlying drift was corrected. |
| `err_1787022038113_c3VPTR` | verify_deploy_gate_unstable | fixed | 84 | `specs/archive/084_fix_duplication_gate_scope_and_extensions_root` — confirmed discharging task. |
| `err_1787026891137_U2A3A4` | delegation_interrupted | unfixed | none | Task 18 (named in the message, Phase 3 interruption) — same task 18 named above; completed per `2a468f6fe`/`6b6307eaf`. Resumed and finished by a later dispatch. |
| `err_1788403658698_8jHcBN` | delegation_interrupted | unfixed | none | **No specific task number is named in the message** ("implement dispatch stopped after phase 6 of 8"). No discharging task identified by id/title search. Follow-up candidate (see below) — superseded in substance, not by a named task, by the progressive-handoff and context-exhaustion-detection mechanisms now standard in every implementation dispatch (`context/patterns/checkpoint-before-overflow.md`, Stage 4D-iii progressive handoffs), which did not exist at the time of this incident and directly target "dispatch stops with no handoff written." |
| `err_1788441471659_EowApA` | delegation_interrupted | unfixed | none | **No specific task number is named in the message** ("impl-147 went idle"; `impl-147` is a dispatch identifier, not a task number). No discharging task identified. Same follow-up-candidate disposition as the entry immediately above: superseded in substance by the now-standard progressive-handoff/context-exhaustion-detection mechanisms, not by a specific named task. |

## Undischarged Findings (Follow-Up Candidates — Not Turned Into Tasks)

Per the plan's Non-Goals, this task does not create follow-up tasks for any undischarged finding;
it only names them. Two records have no specific discharging task:

1. `err_1788403658698_8jHcBN` (delegation_interrupted, generic — "implement dispatch stopped
   after phase 6 of 8", no handoff written)
2. `err_1788441471659_EowApA` (delegation_interrupted, generic — "impl-147 went idle", no handoff
   written)

Both describe the same class of incident (a dispatch stopping without writing a handoff), and
both predate the progressive-handoff / context-exhaustion-detection mechanisms this repository's
implementation agents now follow as standard practice (see
`context/patterns/checkpoint-before-overflow.md` and the Stage 4D-iii progressive-handoff
requirement in `general-implementation-agent.md`). No further action is proposed here; a future
reader who still sees this class of incident recur despite those mechanisms being in place has
grounds for a new task, but that is a deliberate, separate act this task does not take.

## Disposition of the File Itself

`specs/errors.json` is removed via `git rm` after this audit lands. Its content remains fully
reachable in git history (`git log -- specs/errors.json`, or `git show <sha>:specs/errors.json`
for any prior revision) should a future reader need the raw records again.
