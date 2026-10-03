# Mode: Ingest

This file is the COMPLETE and ONLY specification for skill-literature's `Mode: Ingest` (`mode=ingest`) execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Mode: Ingest` section of `skill-literature/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `mode=ingest` is dispatched.

Full pipeline ingestion: convert PDF/DJVU to markdown, chunk hierarchically, index in global SQLite FTS5 database, and optionally load into local specs/literature/.

## Ingest Step 1: Resolve Source Path

```bash
if [ -z "$file" ]; then
  echo "Error: --ingest requires a path or --zotero key."
  echo "Usage: /literature --ingest <path> | /literature --ingest --zotero <key>"
  exit 1
fi
```

## Ingest Step 2: Invoke literature-ingest.sh

Find the ingest script relative to the skill's script directory:

```bash
SCRIPT_DIR="$(dirname "$0")/../../scripts"
INGEST_SCRIPT="$SCRIPT_DIR/literature-ingest.sh"

if [ ! -x "$INGEST_SCRIPT" ]; then
  echo "Error: literature-ingest.sh not found at: $INGEST_SCRIPT"
  exit 1
fi

# Route to ingest script with appropriate flags
if [ -n "$zotero_key" ]; then
  "$INGEST_SCRIPT" --zotero "$zotero_key" "$@"
else
  "$INGEST_SCRIPT" "$file" "$@"
fi
```

Where:
- `$file` is the source path (PDF, DJVU, or directory)
- `$zotero_key` is the Zotero citation key (if using `--zotero`)
- Remaining `$@` may include `--no-local` or `--local` flags

## Ingest Step 3: Display Result

The `literature-ingest.sh` script outputs a summary to stdout on completion. Relay this output to the user verbatim, then add:

```
To search the ingested literature: /literature --search "query"
Or use --lit flag in research/plan/implement commands to enable agent search.
```

## Ingest Examples

```bash
# Ingest a single PDF
/literature --ingest ~/Papers/modal-logic.pdf

# Ingest all PDFs in a directory
/literature --ingest ~/Papers/modal-logic/

# Ingest from Zotero (requires zotero-library.json)
/literature --ingest --zotero "BlackburnDeRijkeVenema2001"

# Ingest and skip local loading prompt
/literature --ingest ~/Papers/modal-logic.pdf --no-local

# Ingest and automatically load into specs/literature/
/literature --ingest ~/Papers/modal-logic.pdf --local
```
