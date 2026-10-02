---
description: Manage specs/literature/ — scan, convert PDFs/DJVUs, maintain index.json, and discover sources
allowed-tools: Skill
argument-hint: [N|"query"|~/path.pdf|~/dir/|--rebuild [--dry-run]|--validate|--index FILE|--convert [FILE]]
---

# Command: /literature

**Purpose**: Manages `specs/literature/` via two modes: (A) Discover — find academic sources by task number or keywords; (B) Integrate — scan/convert PDFs/DJVUs and maintain `index.json`. Also supports `--validate` for index consistency checks and `--rebuild [--dry-run]` to bring the per-repo sub-index (`specs/literature-index.json`) into conformance with the global Literature corpus.
**Layer**: 2 (Command File - Argument Parsing Agent)
**Delegates To**: skill-literature (direct execution)

**Input**: $ARGUMENTS

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Classify arguments into one of three top-level modes:

    **Mode Detection Priority** (first match wins):

    1. `--rebuild` flag anywhere -> Rebuild mode (new; priority-0, checked before `--validate`;
       mutually exclusive with `--validate`/`--index`/`--convert`). `--dry-run` may accompany it.
    2. `--validate` flag anywhere -> Validate mode (kept as-is)
    3. `--index FILE` -> Index mode (kept as-is, integrate path)
    4. `--convert [FILE]` -> Convert mode (kept as-is, integrate path)
    5. No arguments, OR path-like argument -> Integrate mode (Mode B)
    6. Numeric argument (task number), OR text without path characters -> Discover mode (Mode A)

    **Path-like detection**: An argument is path-like if it:
    - Starts with `/`, `~`, or `.`
    - Contains `.pdf` or `.djvu` (case-insensitive)
    - Contains a `/` separator

    **Numeric detection**: An argument is numeric if it matches `^[0-9]+$`

    **Text-only detection**: An argument is a discover query if it:
    - Is NOT path-like
    - Is NOT a flag (does not start with `--`)

    ```
    sub_mode = "integrate"  # default (Mode B)

    args = $ARGUMENTS.split()

    if "--rebuild" in args:
      sub_mode = "rebuild"
      dry_run = "--dry-run" in args  # threaded through as dry_run={true|false}
    elif "--validate" in args:
      sub_mode = "validate"
    elif "--index" in args:
      sub_mode = "index"
      file = extract_arg_after("--index", args) or ""
    elif "--convert" in args:
      sub_mode = "convert"
      file = extract_arg_after("--convert", args) or ""
    elif len(args) == 0:
      sub_mode = "integrate"  # bare /literature -> status/scan
    else:
      # Check first non-flag argument for path-like vs. discover
      first_arg = first_non_flag(args)

      is_path_like = (
        first_arg.startswith("/") or
        first_arg.startswith("~") or
        first_arg.startswith(".") or
        ".pdf" in first_arg.lower() or
        ".djvu" in first_arg.lower() or
        "/" in first_arg
      )

      is_numeric = re.match(r'^[0-9]+$', first_arg)

      if is_path_like:
        sub_mode = "integrate"
        file = first_arg  # path to scan/convert
      elif is_numeric:
        sub_mode = "discover"
        task_num = first_arg
        extra_terms = join(remaining_args_after(first_arg, args))
      else:
        sub_mode = "discover"
        query = join(args)  # entire ARGUMENTS treated as search query
    ```

    **Sub-mode summary**:

    | sub_mode  | Triggered By                             | Delegates To          |
    |-----------|------------------------------------------|-----------------------|
    | discover  | Numeric N, or text without path chars    | Mode A workflow below |
    | integrate | No args, or path-like arg                | skill-literature      |
    | rebuild   | `--rebuild` flag (optional `--dry-run`)  | skill-literature      |
    | validate  | `--validate` flag                        | skill-literature      |
    | index     | `--index FILE`                           | skill-literature      |
    | convert   | `--convert [FILE]`                       | skill-literature      |
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Validate Sub-Mode and Arguments</action>
    <process>
      Validation rules by sub_mode:

      | Sub-Mode  | FILE Required | QUERY/TASK Required | Description |
      |-----------|--------------|---------------------|-------------|
      | discover  | No           | Yes (task_num or query) | Source discovery via three-tier pipeline |
      | integrate | No           | No                  | Scan/convert/status (no args = status) |
      | rebuild   | No           | No                  | Bring per-repo sub-index into conformance with the global corpus (job-picker) |
      | validate  | No           | No                  | Check index.json consistency |
      | index     | Yes          | No                  | Add/update entry for existing markdown file |
      | convert   | Optional     | No                  | Convert specific file or all unprocessed |

      Error messages:
      - index without FILE: "Error: --index requires a FILE argument. Usage: /literature --index path/to/file.md"
      - discover with no terms: "Error: discover mode requires a task number or search query. Usage: /literature N or /literature \"search terms\""
    </process>
  </step_1>

  <step_2>
    <action>Mode A: Discover — Three-Tier Source Discovery</action>
    <process>
      When sub_mode = "discover":

      0. **Assisted Zotero export offer** (runs BEFORE `literature-discover.sh`, via a
         SEPARATE invocation with its own capture -- explicitly NOT `2>/dev/null`, so the
         offer is never swallowed the way the plain `tier2_search()` stderr hint is):

         ```bash
         STATUS_SCRIPT=".claude/scripts/zotero-export-status.sh"
         GENERATE_SCRIPT=".claude/scripts/zotero-generate-export.sh"

         # Both stdout (directive token) AND stderr (rationale) are captured -- neither is
         # discarded. orchestrator_mode is the delegation-context field (true for /orchestrate
         # and other autonomous callers; false for a human-invoked /literature).
         zotero_directive=$("$STATUS_SCRIPT" --orchestrator-mode "$orchestrator_mode" 2>/tmp/zotero-status-rationale.txt)
         zotero_rationale=$(cat /tmp/zotero-status-rationale.txt)
         ```

         Branch on `zotero_directive`:

         - **`ZOTERO_EXPORT_PRESENT`**: An export exists at the resolved path AND is confirmed
           fresh (freshness is delegated entirely to `zotero-export-freshness.sh` inside
           `$STATUS_SCRIPT` -- this command never re-derives it). No offer needed; proceed
           directly to step 1 (main discover call) as today.

         - **`ZOTERO_EXPORT_STALE`**: An export exists at the resolved path, but is NOT
           confirmed fresh (the live Zotero database has been written to since the export was
           generated, its freshness could not be determined, or the freshness helper itself
           failed -- `$STATUS_SCRIPT` folds all three into this single directive; see that
           script's own header for the underlying `zotero-export-freshness.sh` vocabulary). A
           silent zero-result answer from a stale export is exactly the failure mode this whole
           mechanism exists to prevent, so this branch always surfaces something visible rather
           than proceeding quietly.

           **Interactive context** (`orchestrator_mode != true`): issue `AskUserQuestion` with a
           two-option prompt naming the resolved path and both compared dates, drawn directly
           from `zotero_rationale` (captured above) without re-invoking any classifier:

           ```json
           {
             "question": "Your Zotero export at {resolved_path} looks stale (export: {export_date}, Zotero database: {sqlite_date}). Regenerate it now?",
             "header": "Assisted Zotero Export Regeneration",
             "multiSelect": false,
             "options": [
               {
                 "label": "Regenerate now (recommended)",
                 "description": "Runs zotero-generate-export.sh --force, which auto-selects the live-API path (Zotero running) or the offline sqlite-reconstruction path (Zotero closed) on its own -- this offer deliberately does not re-derive that RUNNING/NOT_RUNNING split a second time."
               },
               {
                 "label": "Skip this run",
                 "description": "Continue with the known-stale export for this discovery pass. You can regenerate it later via zotero-generate-export.sh --force."
               }
             ]
           }
           ```

           On **"Regenerate now"**: run `"$GENERATE_SCRIPT" --force --orchestrator-mode false`,
           capturing stdout/stderr the same way the existing "Generate now" handling above does.
           On success, proceed to step 1 with Tier 2 refreshed. On failure (non-zero exit),
           surface the generator's stderr and fall back to step 1 non-fatally (Tier 2 stays on
           the stale snapshot).

           On **"Skip this run"**: log the same explicit "skipped by user choice" notice
           convention used elsewhere in this step, then proceed to step 1 against the known-stale
           export.

           This deliberately does not re-derive the `MISSING_RUNNING`/`MISSING_NOT_RUNNING` UI
           split, because `--force` already auto-selects Path 1 vs Path 3 internally. The
           `orchestrator_mode == true` autonomous default for this same directive is documented
           as its own bullet in the autonomous branch group below, alongside the two existing
           `ZOTERO_EXPORT_MISSING_*` autonomous bullets.

         - **`ZOTERO_EXPORT_MISSING_RUNNING`** (interactive context, `orchestrator_mode !=
           true`): Zotero is already running, so its local API is immediately viable (Path 1).
           Issue `AskUserQuestion` with the two-option prompt:

           ```json
           {
             "question": "No Zotero export found at {resolved_path}. Generate one now from your local Zotero library?",
             "header": "Assisted Zotero Export Generation",
             "multiSelect": false,
             "options": [
               {
                 "label": "Generate now (recommended)",
                 "description": "Zotero is running -- pulls your whole library live via its local API (and enriches citation-keys via Better BibTeX if installed). This writes a ONE-TIME SNAPSHOT (not Zotero's auto-refreshing \"Keep updated\" export) plus a staleness stamp; re-run the generator later to refresh."
               },
               {
                 "label": "Skip this run",
                 "description": "Continue without a Zotero export; Tier 2 stays skipped for this discovery pass. You can generate it later via zotero-generate-export.sh."
               }
             ]
           }
           ```

           On "Generate now": run `"$GENERATE_SCRIPT" --orchestrator-mode false`, capturing
           stdout (resolved output path) and stderr (progress/rationale, including the
           staleness-stamp note); on success (exit 0), proceed to step 1 (main discover call,
           Tier 2 now populated). On failure (non-zero exit, e.g. a race where Zotero closed
           mid-run), surface the generator's stderr and fall back to step 1 as today (Tier 2
           stays skipped, non-fatal).

           On "Skip this run": log a visible, explicit "Zotero export generation skipped by
           user choice" notice (non-silent because it is a chosen option, not a default), then
           proceed to step 1.

         - **`ZOTERO_EXPORT_MISSING_NOT_RUNNING`** (interactive context, `orchestrator_mode !=
           true`): Zotero is closed. Issue `AskUserQuestion` with THREE options. The primary
           choice is now opening Zotero and retrying via the live API (Path 1 -- richer, and
           data-dir-agnostic since it never touches the sqlite file directly); the offline
           sqlite snapshot (Path 3) is kept as an explicit secondary; skip remains:

           ```json
           {
             "question": "No Zotero export found at {resolved_path}, and Zotero does not appear to be running. How would you like to proceed?",
             "header": "Assisted Zotero Export Generation",
             "multiSelect": false,
             "options": [
               {
                 "label": "Open Zotero, then retry (recommended)",
                 "description": "Open the Zotero desktop app, then retry here. Once running, this pulls your whole library live via Zotero's local API (and enriches citation-keys via Better BibTeX if installed) -- richer, and works regardless of any custom Zotero Data Directory setting."
               },
               {
                 "label": "Generate an offline snapshot without opening Zotero",
                 "description": "Reconstructs a ONE-TIME SNAPSHOT directly from your local Zotero sqlite database while Zotero stays closed (plus a staleness stamp; re-run the generator later to refresh)."
               },
               {
                 "label": "Skip this run",
                 "description": "Continue without a Zotero export; Tier 2 stays skipped for this discovery pass. You can generate it later via zotero-generate-export.sh."
               }
             ]
           }
           ```

           **On "Open Zotero, then retry"**: enter a bounded retry loop, capped at **3 attempts
           total** (this explicit cap guarantees the loop cannot run forever if Zotero is never
           actually opened, or opens with its local API disabled):

           1. Set `attempt = 1`.
           2. Re-invoke the classifier: `zotero_directive=$("$STATUS_SCRIPT" --orchestrator-mode
              false 2>/tmp/zotero-status-rationale.txt)`.
           3. If `zotero_directive` is now `ZOTERO_EXPORT_MISSING_RUNNING`: run
              `"$GENERATE_SCRIPT" --orchestrator-mode false` (Path 1, live pull), using the SAME
              success/failure handling as "Generate now" above, then STOP the loop and proceed to
              step 1.
           4. Otherwise, if `attempt < 3`: issue `AskUserQuestion` with options
              `["I've opened Zotero — retry now", "Generate an offline snapshot instead", "Skip
              this run"]`. On "retry now": increment `attempt` and go back to step 2. On
              "Generate an offline snapshot instead" or "Skip this run": break out of the loop
              and fall through to the corresponding handling below.
           5. Otherwise (`attempt == 3` and still not `ZOTERO_EXPORT_MISSING_RUNNING` -- Zotero
              was never opened, or is open but its local API stayed unreachable): surface this
              freshly-authored enable-API guidance, matching the numbered-heredoc style of
              `zotero-search.sh:143-169`:

              ```
              Zotero's local API is still not reachable after 3 attempts.

              If Zotero is open but this keeps failing, its local API sharing setting may be
              disabled:

              1. In Zotero, go to:
                 Zotero Settings -> Advanced -> API
              2. Check the box:
                 "Allow other applications on this computer to communicate with Zotero"
              3. Retry `/literature` once the box is checked -- no restart of Zotero should be
                 required.
              ```

              Then present a final `AskUserQuestion` with `["Generate an offline snapshot
              instead", "Skip this run"]` and fall through to the corresponding handling below.

           **On "Generate an offline snapshot without opening Zotero"** (whether chosen directly
           from the initial three-option prompt, or reached after the retry loop above): run
           `"$GENERATE_SCRIPT" --orchestrator-mode false` (Path 3, sqlite reconstruction against
           the resolved sqlite path), using the SAME success/failure handling as "Generate now"
           above (capture stdout/stderr; proceed to step 1 on success with Tier 2 populated; on
           failure surface the generator's stderr and fall back to step 1 non-fatally, Tier 2
           stays skipped).

           **On "Skip this run"** (whether chosen directly, or reached after the retry loop):
           log the same visible, explicit "Zotero export generation skipped by user choice"
           notice as above, then proceed to step 1.

         - **`ZOTERO_EXPORT_UNAVAILABLE`**: No offer. Surface the zotero-search.sh-matching
           manual-setup steps directly (no local Zotero data source exists to generate from):

           ```
           No Zotero export found, and no local Zotero installation was detected either
           (Zotero's local API is unreachable and no zotero.sqlite was found at the resolved
           sqlite path).

           To set up Zotero CSL-JSON export manually:
           1. Install the Better BibTeX plugin for Zotero: https://retorque.re/zotero-better-bibtex/
           2. In Zotero, go to: File -> Export Library...
           3. Choose format: "Better CSL JSON"  Check "Keep updated" for automatic re-export.
           4. Save to one of: $ZOTERO_LIBRARY / ${LITERATURE_DIR}/zotero-library.json / ~/Projects/Literature/zotero-library.json
           ```

           Then proceed to step 1 (Tier 2 stays skipped, non-fatal, as today).

         - **Orchestrator / non-interactive default, `ZOTERO_EXPORT_STALE`**
           (`orchestrator_mode == true`): `AskUserQuestion` cannot prompt a human, so it MUST
           NOT be called. Take the deterministic default and run `"$GENERATE_SCRIPT" --force
           --orchestrator-mode true`; emit a visible `[zotero:auto]` notice stating that
           regeneration was auto-selected because the export is stale and no human is available
           to prompt -- this is NEVER a silent no-op, and mirrors the same `AUTONOMOUS_GLOBAL`
           precedent from the `--lit` flow that the two sibling autonomous bullets below already
           follow (see CLAUDE.md "Literature Mode" section). Then proceed to step 1 regardless of
           the regeneration outcome (non-fatal): the point of this branch is that staleness was
           at least visibly acted on, not that regeneration is guaranteed to succeed.

         - **Orchestrator / non-interactive default, `ZOTERO_EXPORT_MISSING_RUNNING`**
           (`orchestrator_mode == true`): `AskUserQuestion` cannot prompt a human, so it MUST
           NOT be called. Zotero's local API is already viable, so take the deterministic
           default "generate now": run `"$GENERATE_SCRIPT" --orchestrator-mode true` and emit a
           visible `[zotero:auto]` notice explaining the autonomous choice -- this is NEVER a
           silent no-op, and mirrors the `AUTONOMOUS_GLOBAL` precedent from the `--lit` flow
           (see CLAUDE.md "Literature Mode" section). Then proceed to step 1 regardless of the
           generation outcome (Tier 2 either becomes populated or stays skipped, non-fatal).

         - **Orchestrator / non-interactive default, `ZOTERO_EXPORT_MISSING_NOT_RUNNING`**
           (`orchestrator_mode == true`): `AskUserQuestion` cannot prompt a human, and there is
           no human available to open Zotero, so this branch does **not** loop and does **not**
           prompt (unlike the interactive branch above) -- it does not duplicate a data-source
           pre-check here either. It still runs `"$GENERATE_SCRIPT" --orchestrator-mode true`
           directly (a resolved sqlite path is a legitimate non-interactive success path via
           Path 3, post-FIX-1). The "never write an empty file, fail loudly instead" guarantee
           is now BROADER than just the genuine no-data-source case: it also covers a Path 1
           pagination failure partway through (no partial/truncated write, non-zero exit) and
           the content-keyed shrink guard (see below). All three are concentrated entirely
           inside the generator's own hardened logic (see `zotero-generate-export.sh`) -- this
           command layer does not re-implement any of it, and does not need to distinguish exit
           1 (no data source, or a pagination failure) from exit 4 (shrink guard blocked) to
           stay correct: both are simply "generation failed this run, Tier 2 stays on whatever
           it had before," surfaced via loud stderr, never silent. Then proceed to step 1
           regardless of the generation outcome (Tier 2 either becomes populated or stays
           skipped, non-fatal; a generator failure here is surfaced via its loud stderr error,
           never silent).

         **Shrink guard note (all branches above that call `$GENERATE_SCRIPT`)**: the generator
         now refuses to overwrite an existing export with one containing dramatically fewer
         items (more than a 10% shrink, or zero items) unless `--allow-shrink` is also passed,
         exiting 4 with no write when blocked. This is DISTINCT from `--force`: `--force` gates
         whether an existing file may be regenerated AT ALL (existence-keyed, pre-fetch, exit 3
         if omitted); `--allow-shrink` gates whether a freshly fetched, materially smaller
         result may actually overwrite it (content-keyed, post-fetch, exit 4 if omitted). None
         of the invocations above pass `--allow-shrink` -- a run that trips the guard surfaces
         its diagnostic (previous count, candidate count, threshold, and the exact
         `--allow-shrink` invocation to override) via loud stderr and Tier 2 stays on the prior
         export, same as any other non-fatal generation failure in this step. A human re-running
         `zotero-generate-export.sh` directly with `--allow-shrink` is the intended recovery path
         when the shrink is expected (e.g. immediately after a Path 3 itemTypeID correction, or
         a genuine library deletion) -- this command does not auto-pass it.

         This offer is a SEPARATE classifier invocation from the main discover call below; it
         never touches `literature-discover.sh`'s pure-JSON-array stdout contract. The main
         call's own stderr is now captured too (never discarded) — see step 1 immediately below
         — so a Tier 3 partial failure inside the main discovery pass is surfaced the same way
         this Zotero offer's own rationale already is.

      1. **Run `literature-discover.sh`**, capturing stderr instead of discarding it (the same
         capture-to-file pattern used for `zotero_directive`/`zotero_rationale` above, so a Tier 3
         `TIER3_STATUS: FAILED` notice — see `literature-discover.sh`'s `tier3_search()` header
         comment for the stderr contract — reaches this command layer instead of being silently
         thrown away):
         ```bash
         DISCOVER_SCRIPT=".claude/scripts/literature-discover.sh"

         if [ -n "$task_num" ] && [ -n "$extra_terms" ]; then
           discover_results=$("$DISCOVER_SCRIPT" --task "$task_num" "$extra_terms" 2>/tmp/discover-rationale.txt)
           discover_exit=$?
         elif [ -n "$task_num" ]; then
           discover_results=$("$DISCOVER_SCRIPT" --task "$task_num" 2>/tmp/discover-rationale.txt)
           discover_exit=$?
         else
           discover_results=$("$DISCOVER_SCRIPT" "$query" 2>/tmp/discover-rationale.txt)
           discover_exit=$?
         fi
         discover_rationale=$(cat /tmp/discover-rationale.txt)
         ```

         Branch on `discover_rationale`: if it contains the line `TIER3_STATUS: FAILED`, set
         `tier3_failed=true` and extract the `http_code=` value from that line for use in the
         notice text below (e.g. via `grep -o 'http_code=[^ ]*' <<< "$discover_rationale"`).
         Otherwise `tier3_failed=false` — Tier 3 either succeeded (possibly with zero matches) or
         was skipped for having no rolled-forward quota (`literature-discover.sh` never emits
         `TIER3_STATUS: FAILED` for a genuine quota-zero skip, so this branch cannot
         false-positive on that case).

      2. **Handle no-results case** (exit code 1):
         ```
         No sources found for: "{query}"

         Suggestions:
           - Try broader search terms
           - Check that LITERATURE_DIR is set correctly (currently: {LITERATURE_DIR})
           - Ensure network connectivity for online search (Tier 3)
         ```

         If `tier3_failed` is `true`, append:
         ```
         Online search (Tier 3) failed: rate-limited or unreachable (http_code={code}) — this run
         is not evidence that nothing exists online. Retry later before concluding the search was
         exhaustive.
         ```

      3. **Present results via AskUserQuestion** (multi-select). If `tier3_failed` is `true`
         (set in step 1), prepend this notice to the question text so a partial result set is
         never read as complete:
         ```
         Note: online search (Tier 3) failed: rate-limited or unreachable (http_code={code}) —
         these results may be incomplete, not exhaustive.
         ```
         ```json
         {
           "question": "Found {N} sources for '{query}'. Select sources to add to SOURCES.md:",
           "header": "Source Discovery Results",
           "multiSelect": true,
           "options": [
             {
               "label": "[Tier 1 - LOCAL] Title of Available Paper",
               "description": "Authors: Author Name | Year: 2023 | Status: available | Path: ~/Projects/Literature/..."
             },
             {
               "label": "[Tier 2 - ZOTERO] Title of Zotero Paper",
               "description": "Authors: Author Name | Year: 2022 | Status: in_zotero | doc_id: author2022_title"
             },
             {
               "label": "[Tier 3 - OPEN ACCESS] Title of OA Paper",
               "description": "Authors: Author Name | Year: 2021 | Status: open_access | PDF: https://arxiv.org/..."
             },
             {
               "label": "[Tier 3 - PAYWALL] Title of Paywalled Paper",
               "description": "Authors: Author Name | Year: 2020 | Status: paywall | DOI: 10.1234/..."
             },
             {
               "label": "Done — no selection",
               "description": "Exit without adding to SOURCES.md"
             }
           ]
         }
         ```

      3.5. **Offer online ingestion for eligible entries** (new branch; runs BEFORE step 4, for
          each SELECTED entry whose status is `open_access`, `paywall`, or `in_zotero_no_pdf` —
          `available`/`in_zotero` entries already have a local file or Zotero PDF and skip this
          branch entirely, unaffected). Numbered "3.5" (not "3b") to avoid any confusion with the
          unrelated top-level `<step_3b>` XML tag (rebuild mode) elsewhere in this command file:

          If one or more eligible entries were selected, issue `AskUserQuestion`:
          ```json
          {
            "question": "N of your selected sources can be ingested into the Literature corpus now (Zotero item + PDF + corpus chunks). Which should be ingested?",
            "header": "Online Ingest into Literature",
            "multiSelect": true,
            "options": [
              {
                "label": "Title of OA/arXiv Paper",
                "description": "Status: open_access | PDF: https://arxiv.org/pdf/... — ingest now, or skip to record in SOURCES.md only"
              },
              {
                "label": "Title of In-Zotero-No-PDF Paper",
                "description": "Status: in_zotero_no_pdf | Zotero item exists but has no PDF attached yet — attach + ingest now, or skip"
              },
              {
                "label": "Title of Paywalled Paper",
                "description": "Status: paywall — no PDF is known; ingesting will likely just confirm this honestly and fall back to SOURCES.md"
              },
              {
                "label": "None — just record in SOURCES.md (default)",
                "description": "Skip online ingestion for all of the above; today's SOURCES.md-only behavior"
              }
            ]
          }
          ```

          For each entry the user opts into (NOT "None"): invoke `literature-ingest-online.sh`
          with that entry's full discovery-record JSON:
          ```bash
          directive=$(echo "$entry_json" | .claude/scripts/literature-ingest-online.sh 2>/tmp/online-ingest-rationale.txt)
          ingest_exit=$?
          rationale=$(cat /tmp/online-ingest-rationale.txt)
          ```

          Branch on `directive` (both stdout token AND stderr rationale are captured, never
          discarded — mirrors the `zotero-export-status.sh`/`zotero_directive` pattern above):
          - **`ONLINE_INGEST_INGESTED`** or **`ONLINE_INGEST_ATTACHED`** (exit 0): full success.
            Mark this entry as "already ingested" for steps 4/5 below — it gets a `[RESOLVED]`
            SOURCES.md row (not the status-based row) and is NOT separately added to the
            sub-index in step 5 (the script itself already registered it in
            `specs/literature-index.json`).
          - **`ONLINE_INGEST_INGESTED_NO_ATTACHMENT`** (exit 0): create-item path, resolved
            (translation-server) metadata branch only — the Zotero item was created but the
            separate attach-file call did not succeed (e.g. quota-skipped or a real attach
            failure). Treat identically to `ONLINE_INGEST_INGESTED` for the `[RESOLVED]`
            SOURCES.md row and sub-index purposes (the item exists and corpus ingest already
            succeeded), but surface `rationale` visibly so the missing PDF attachment is not a
            silent gap — never conflate with a full-success row without noting the caveat.
          - **`ONLINE_INGEST_NO_PDF`** (exit 1): honest, no-side-effect stop (paywall, or no
            discoverable PDF for an in_zotero_no_pdf item). Surface `rationale` visibly, then
            fall through to steps 4/5 exactly as if the user had chosen "None" for this entry —
            never a silent failure, never a fabricated success.
          - **`ONLINE_INGEST_DOWNLOAD_FAILED`** (exit 2): the PDF failed the magic-byte gate or
            could not be downloaded. Surface `rationale` visibly (this is the "cookie-wall/
            landing-page" case), then fall through to steps 4/5 as today (no fabricated
            download; no Zotero write was attempted).
          - **`ONLINE_INGEST_ZOTERO_CREATE_FAILED`** / **`ONLINE_INGEST_ZOTERO_RESOLVE_FAILED`**
            / **`ONLINE_INGEST_ZOTERO_ATTACH_FAILED`** / **`ONLINE_INGEST_PIPELINE_FAILED`**
            (exit 3/4/5/6): surface `rationale` visibly as an error (not a silent fallback —
            these indicate the ingest was attempted but failed partway), then fall through to
            steps 4/5 as today so the entry is at least recorded in SOURCES.md.

          If the user selects "None" (or no eligible entries were selected at all): skip this
          branch entirely, proceed to steps 4/5 unchanged (today's SOURCES.md-only behavior for
          every eligible entry — the honest, always-available fallback).

      4. **Update `specs/literature/SOURCES.md`** for selected entries:

         For each selected result:
         - If status = "available": skip SOURCES.md entry (already imported), show path
         - If marked "already ingested" by step 3.5: add row with status `[RESOLVED]`, note the
           doc_id (this document is now fully in the corpus — Zotero item + PDF + corpus chunks
           + sub-index entry — not merely tracked)
         - If status = "in_zotero": add row with status `[IN_ZOTERO]`
         - If status = "in_zotero_no_pdf" (not ingested this run): add row with status `[PENDING]`
         - If status = "open_access" (not ingested this run): add row with status `[FOUND]`, include PDF URL in Notes
         - If status = "paywall" (not ingested this run): add row with status `[PAYWALL]`, include DOI in Notes

         SOURCES.md format:
         ```markdown
         # Literature Sources

         | Title | Authors | Year | DOI | Status | Notes |
         |-------|---------|------|-----|--------|-------|
         | Paper Title | Author Name | 2023 | 10.1234/x | [IN_ZOTERO] | zotero: citation_key |
         | OA Paper | Author2 | 2022 | 10.5678/y | [FOUND] | pdf: https://arxiv.org/pdf/2201.1234 |
         | Paywalled | Author3 | 2021 | 10.9012/z | [PAYWALL] | |
         | Ingested Paper | Author4 | 2021 | 10.3456/w | [RESOLVED] | doc_id: author4_2021_paper (ingested via online-ingest bridge) |
         ```

         If `specs/literature/SOURCES.md` does not exist, create it with the header row.
         If it already exists, append new rows (check for duplicate titles before appending).

      5. **Update `specs/literature-index.json`** sub-index (only for "available", "in_zotero",
         and entries marked "already ingested" by step 3.5):
         - For "available" entries that resolve to a path in LITERATURE_DIR: add entry to local sub-index
         - For entries marked "already ingested" by step 3.5: SKIP — `literature-ingest-online.sh`
           already registered the sub-index entry itself (source: "discover"); adding it again
           here would be redundant, not idempotent-safe duplication
         - Skip sub-index update for any remaining online/paywall sources not ingested this run
           (not yet local)

         ```bash
         LOCAL_INDEX="specs/literature-index.json"
         if [ ! -f "$LOCAL_INDEX" ]; then
           echo '{"entries": []}' > "$LOCAL_INDEX"
         fi
         # Add entries for local sources with doc_id, title, authors, year, path, status
         # (entries already registered by literature-ingest-online.sh in step 3.5 are skipped)
         ```
    </process>
  </step_2>

  <step_3>
    <action>Mode B: Integrate — Delegate to Literature Skill</action>
    <process>
      When sub_mode = "integrate" (no args or path-like arg):

      If a path argument was given (file path to PDF/DJVU or directory):
        - Set mode = "convert", file = {path_arg}
        - Delegate to skill-literature with args: "mode=convert file={path_arg}"
      Else (no arguments):
        - Set mode = "status"
        - Delegate to skill-literature with args: "mode=status"
    </process>
  </step_3>

  <step_3b>
    <action>Mode: rebuild — Delegate to Literature Skill</action>
    <process>
      When sub_mode = "rebuild": delegate to skill-literature with `mode=rebuild` and the
      `dry_run` value parsed in argument_parsing step_1 (defaults to `false` if `--dry-run` was
      not present). The `file` argument is unused for this mode.
    </process>
    <input>
      - skill: "skill-literature"
      - args: "mode=rebuild dry_run={true|false}"
    </input>
    <expected_return>
      {
        "status": "completed",
        "mode": "rebuild",
        "dry_run": true|false,
        "sub_index_status": "present|absent|deferred_to_setup_task",
        "jobs_run": ["dangling_ref_lint", "schema_conformance", ...],
        "report": "..."
      }
    </expected_return>
  </step_3b>

  <step_4>
    <action>Modes: validate, index, convert — Delegate to Literature Skill</action>
    <input>
      - skill: "skill-literature"
      - args: "mode={sub_mode} file={file}" (for validate/index/convert)
    </input>
    <expected_return>
      {
        "status": "completed",
        "mode": "{sub_mode}",
        "files_processed": N,
        "index_entries": M,
        "report": "..."
      }
    </expected_return>
  </step_4>

  <step_5>
    <action>Present Results</action>
    <process>
      Discover mode:
        - Show Tier breakdown (N local, M Zotero, P online)
        - Show count of entries added to SOURCES.md
        - Suggest: "Run /literature ~/path/to/file.pdf to convert a paper, or use --lit to inject literature into agent prompts"

      Integrate mode (status):
        - Display processed vs unprocessed file counts
        - Show index.json health summary
        - Show any warnings (missing files, stale entries)
        - Suggest next actions

      Convert mode:
        - Display converted file names and token counts
        - Show index.json entries added/updated
        - Report any files skipped (scanned-only PDFs, missing djvutxt)

      Validate mode:
        - List stale entries (path in index.json but file missing)
        - List unindexed files (markdown files not in index.json)
        - Show token count drift warnings (>20% change)
        - Suggest: "Run /literature --index FILE to add unindexed entries"

      Rebuild mode:
        - If the sub-index was absent: report that a setup task was created/deferred to (per
          `handle_rebuild()`'s absent-sub-index path); no job picker was shown.
        - Otherwise: show the multi-job aggregated report from `handle_rebuild()` — dangling-ref
          lint results, schema-conformance results, coverage-refresh diff/confirmation outcome
          (or "skipped — not selected"), and the coverage-audit's per-directory missing list.
        - If `--dry-run` was active, prefix the report with a note that Job 3 (if selected) only
          printed a proposed diff and wrote nothing.

      Index mode:
        - Confirm entry added/updated in index.json
        - Show keywords and summary used
    </process>
  </step_5>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - Unknown flag -> "Unknown flag: {flag}. Available: --rebuild [--dry-run], --validate, --convert [FILE], --index FILE, or pass a task number N or search query for discovery"
    - --index without FILE -> "Error: --index requires a FILE argument. Usage: /literature --index path/to/file.md"
    - discover with no terms -> "Error: discover mode requires a task number or search query. Usage: /literature 714 or /literature \"modal logic\""
    - Task N not found in state.json -> "Error: Task N not found in specs/state.json. Check the task number and try again."
  </argument_errors>

  <execution_errors>
    - literature-discover.sh not found -> "Error: literature-discover.sh not found at .claude/scripts/literature-discover.sh"
    - literature-discover.sh returns exit 1 (no results) -> Show "No sources found" message with suggestions (see Workflow step 2)
    - literature-discover.sh returns exit 2 (arg error) -> Pass through error message from script
    - literature-discover.sh stderr contains `TIER3_STATUS: FAILED` (Tier 3 rate-limited or
      unreachable; exit code is otherwise 0 or 1 depending on whether Tiers 1/2 found anything) ->
      not a hard error; surface the partial-failure notice on both the no-results path (Workflow
      step 2) and the results-found path (Workflow step 3) rather than treating the run as either
      complete or fully failed
    - specs/literature/ missing -> "No specs/literature/ directory found. Create it and add PDF/DJVU files to convert."
    - pdftotext not available -> "pdftotext not found. Install with: nix-env -iA nixpkgs.poppler_utils"
    - djvutxt not available -> "djvutxt not found (DJVU files will be skipped). Install with: nix-env -iA nixpkgs.djvulibre"
    - Skill failure -> Return error details
  </execution_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    Mode A (discover):
    - $LITERATURE_DIR/index.json (Tier 1: global index search)
    - $LITERATURE_DIR/zotero-library.json (Tier 2: via zotero-search.sh)
    - https://api.semanticscholar.org/ (Tier 3: online API)
    - https://api.unpaywall.org/ (Tier 3: OA fallback for DOIs)
    - specs/state.json (when --task N given: read task slug for search terms)

    Mode B (integrate):
    - specs/literature/ (PDF/DJVU source files — gitignored, co-located with markdown)
    - specs/literature/ (markdown conversion files)
    - specs/literature/index.json (current index state)
  </reads>

  <writes>
    Mode A (discover):
    - specs/literature/SOURCES.md (append discovered sources as markdown table rows)
    - specs/literature-index.json (sub-index entries for "available" and "in_zotero" sources)

    Mode B (integrate):
    - specs/literature/*.md (flat document conversions)
    - specs/literature/{docname}/sectionNN_{slug}.md (content-aware chunked sections)
    - specs/literature/{docname}/{docname}_partNN.md (mechanical fallback chunks)
    - specs/literature/index.json (index entries with enriched schema: authors, title, year, doc_type, source_format, parent_doc, page_range)
    - $LITERATURE_DIR/pdfs/{citation_key}.pdf (symlink to Zotero PDF, for import)
    - $LITERATURE_DIR/index.json (Zotero metadata fields: bib_key, zotero_key, zotero_path, project_tags)
  </writes>

  <source_file_convention>
    Source PDFs/DJVUs are placed in the same directory as their converted markdown.
    Gitignore patterns `specs/literature/**/*.pdf` and `specs/literature/**/*.djvu` prevent
    committing source files. Users re-add source files manually after checkout.
  </source_file_convention>

  <sources_md_convention>
    `specs/literature/SOURCES.md` is created by Mode A (discover) on first use.
    It serves as a human-readable tracking table for papers identified but not yet imported.
    Status progression: [PENDING] -> [IN_ZOTERO] -> [FOUND] -> [RESOLVED]
    Papers marked [PAYWALL] require manual acquisition before they can progress.
    Papers marked [RESOLVED] have been fully imported and indexed via Mode B (integrate).
  </sources_md_convention>
</state_management>
