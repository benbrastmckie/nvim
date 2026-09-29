#!/usr/bin/env bash
# generate-zotero-sqlite-fixture.sh - Build a minimal, schema-faithful synthetic Zotero
# sqlite database for testing fetch_path3() (direct sqlite reconstruction) fully offline, with
# NO running Zotero and no copy of a real zotero.sqlite. Covers exactly the tables and columns
# fetch_path3()'s query reads: items, itemTypes, libraries, itemData/itemDataValues/
# fieldsCombined, itemCreators/creators, itemTags/tags, itemAttachments.
#
# Deliberately seeds itemTypes with the historical WRONG numeric IDs this task's Phase 5 fixed
# (1/3/28 as artwork/audioRecording/podcast, distinct from the real attachment/note/annotation
# IDs) so a regression to the old hardcoded `NOT IN (1, 3, 28)` form would be caught: this
# fixture's bibliographic-only count only matches the CORRECT name-keyed exclusion.
#
# USAGE:
#   generate-zotero-sqlite-fixture.sh DB_PATH [--bib N] [--attachment N] [--note N]
#     [--annotation N]
#
# OPTIONS:
#   DB_PATH          Output sqlite file path (overwritten if it exists).
#   --bib N          Number of bibliographic (journalArticle) items to seed (default 10).
#   --attachment N   Number of attachment items to seed (default 3).
#   --note N         Number of note items to seed (default 2).
#   --annotation N   Number of annotation items to seed (default 4).
#
# OUTPUT:
#   stdout: DB_PATH on success.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "generate-zotero-sqlite-fixture.sh: DB_PATH is required" >&2
  exit 2
fi

DB_PATH="$1"
shift

BIB_COUNT=10
ATTACHMENT_COUNT=3
NOTE_COUNT=2
ANNOTATION_COUNT=4

while [ $# -gt 0 ]; do
  case "$1" in
    --bib) BIB_COUNT="${2:-10}"; shift 2 ;;
    --attachment) ATTACHMENT_COUNT="${2:-3}"; shift 2 ;;
    --note) NOTE_COUNT="${2:-2}"; shift 2 ;;
    --annotation) ANNOTATION_COUNT="${2:-4}"; shift 2 ;;
    *)
      echo "generate-zotero-sqlite-fixture.sh: unrecognized argument '$1'" >&2
      exit 2
      ;;
  esac
done

rm -f "$DB_PATH"

sqlite3 "$DB_PATH" << 'SCHEMA'
CREATE TABLE itemTypes (itemTypeID INTEGER PRIMARY KEY, typeName TEXT);
CREATE TABLE libraries (libraryID INTEGER PRIMARY KEY, type TEXT);
CREATE TABLE items (itemID INTEGER PRIMARY KEY, key TEXT, itemTypeID INTEGER, libraryID INTEGER);
CREATE TABLE fieldsCombined (fieldID INTEGER PRIMARY KEY, fieldName TEXT);
CREATE TABLE itemDataValues (valueID INTEGER PRIMARY KEY, value TEXT);
CREATE TABLE itemData (itemID INTEGER, fieldID INTEGER, valueID INTEGER);
CREATE TABLE creators (creatorID INTEGER PRIMARY KEY, lastName TEXT, firstName TEXT);
CREATE TABLE itemCreators (itemID INTEGER, creatorID INTEGER, creatorTypeID INTEGER, orderIndex INTEGER);
CREATE TABLE tags (tagID INTEGER PRIMARY KEY, name TEXT);
CREATE TABLE itemTags (itemID INTEGER, tagID INTEGER);
CREATE TABLE itemAttachments (itemID INTEGER, parentItemID INTEGER, contentType TEXT, path TEXT);

-- Deliberately includes the historical WRONG IDs (1, 3, 28) as UNRELATED types, so a
-- regression to hardcoded numeric-ID exclusion is caught rather than accidentally passing.
INSERT INTO itemTypes (itemTypeID, typeName) VALUES
  (1, 'artwork'),
  (3, 'audioRecording'),
  (28, 'podcast'),
  (2, 'attachment'),
  (26, 'note'),
  (37, 'annotation'),
  (4, 'journalArticle');

INSERT INTO libraries (libraryID, type) VALUES (1, 'user');

INSERT INTO fieldsCombined (fieldID, fieldName) VALUES
  (110, 'title'),
  (120, 'abstractNote'),
  (14, 'date');
SCHEMA

python3 - "$DB_PATH" "$BIB_COUNT" "$ATTACHMENT_COUNT" "$NOTE_COUNT" "$ANNOTATION_COUNT" << 'PYEOF'
import sqlite3
import sys

db_path, bib_n, attachment_n, note_n, annotation_n = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])

con = sqlite3.connect(db_path)
cur = con.cursor()

item_id = 1
value_id = 1

def add_bib_item(item_type_id, idx):
    global item_id, value_id
    key = f"BIB{idx:05d}"
    cur.execute("INSERT INTO items (itemID, key, itemTypeID, libraryID) VALUES (?, ?, ?, 1)", (item_id, key, item_type_id))
    title_value_id = value_id
    cur.execute("INSERT INTO itemDataValues (valueID, value) VALUES (?, ?)", (value_id, f"Title {idx}"))
    value_id += 1
    cur.execute("INSERT INTO itemData (itemID, fieldID, valueID) VALUES (?, 110, ?)", (item_id, title_value_id))

    date_value_id = value_id
    cur.execute("INSERT INTO itemDataValues (valueID, value) VALUES (?, ?)", (value_id, "2020-01-01"))
    value_id += 1
    cur.execute("INSERT INTO itemData (itemID, fieldID, valueID) VALUES (?, 14, ?)", (item_id, date_value_id))

    creator_id = item_id * 100
    cur.execute("INSERT INTO creators (creatorID, lastName, firstName) VALUES (?, ?, ?)", (creator_id, f"Author{idx}", "A"))
    cur.execute("INSERT INTO itemCreators (itemID, creatorID, creatorTypeID, orderIndex) VALUES (?, ?, 8, 0)", (item_id, creator_id))

    result_key = key
    item_id += 1
    return result_key

def add_non_bib_item(item_type_id, idx, prefix):
    global item_id
    key = f"{prefix}{idx:05d}"
    cur.execute("INSERT INTO items (itemID, key, itemTypeID, libraryID) VALUES (?, ?, ?, 1)", (item_id, key, item_type_id))
    item_id += 1
    return key

bib_keys = [add_bib_item(4, i) for i in range(bib_n)]
attachment_keys = [add_non_bib_item(2, i, "ATT") for i in range(attachment_n)]
note_keys = [add_non_bib_item(26, i, "NOTE") for i in range(note_n)]
annotation_keys = [add_non_bib_item(37, i, "ANNOT") for i in range(annotation_n)]

con.commit()
con.close()

print(f"bib_keys={','.join(bib_keys)}", file=sys.stderr)
print(f"attachment_keys={','.join(attachment_keys)}", file=sys.stderr)
print(f"note_keys={','.join(note_keys)}", file=sys.stderr)
print(f"annotation_keys={','.join(annotation_keys)}", file=sys.stderr)
PYEOF

echo "$DB_PATH"
