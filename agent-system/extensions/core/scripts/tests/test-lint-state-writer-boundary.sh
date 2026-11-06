#!/usr/bin/env bash
# test-lint-state-writer-boundary.sh - Both-polarity fixture test for
# scripts/lint/lint-state-writer-boundary.sh.
#
# The lint's job is to fail when a hand-rolled `jq ... > <staging> && mv <staging> state.json`
# sequence reappears anywhere in the source store, and to stay silent when the same write is
# routed through scripts/state-write.sh. This test asserts both polarities against synthetic
# fixtures written to a scratch directory, so it never depends on the live tree being clean (that
# is a separate, whole-tree assertion) and never mutates the repository.
#
# Structural model: test-lint-postflight-boundary.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, pass()/fail()/info() helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_candidate "lint-state-writer-boundary.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-state-writer-boundary.sh" \
  "$SCRIPT_DIR/../lint/lint-state-writer-boundary.sh")" || exit 2

PASSED=0
FAILED=0
common_test_workdir_init

# =====================================================================
# Case 1 (negative polarity): hand-rolled staged write -> lint must fail (non-zero)
# =====================================================================
common_test_info "=== negative case: hand-rolled staged write ==="

DIRTY_DIR="$WORKDIR/dirty"
mkdir -p "$DIRTY_DIR"
DIRTY_FIXTURE="$DIRTY_DIR/synthetic-dirty-command.md"
cat > "$DIRTY_FIXTURE" << 'EOF'
# Synthetic Dirty Fixture

Update the task record:

```bash
jq '.foo = "bar"' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```
EOF

if bash "$LINT_SCRIPT" "$DIRTY_DIR" >"$WORKDIR/dirty-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for a hand-rolled staged state.json write (expected non-zero)"
else
  common_test_pass "lint exited non-zero for a hand-rolled staged state.json write"
fi

if grep -q "synthetic-dirty-command.md:6" "$WORKDIR/dirty-out.txt"; then
  common_test_pass "lint reports the violation with file:line"
else
  common_test_fail "lint output did not name the violating file:line:
$(cat "$WORKDIR/dirty-out.txt")"
fi

# =====================================================================
# Case 2 (positive polarity): equivalent state-write.sh call -> lint must pass (exit 0)
# =====================================================================
common_test_info "=== positive case: routed through state-write.sh ==="

CLEAN_DIR="$WORKDIR/clean"
mkdir -p "$CLEAN_DIR"
CLEAN_FIXTURE="$CLEAN_DIR/synthetic-clean-command.md"
cat > "$CLEAN_FIXTURE" << 'EOF'
# Synthetic Clean Fixture

Update the task record:

```bash
.claude/scripts/state-write.sh '.foo = "bar"' --session-id "$SESSION_ID"
```
EOF

if bash "$LINT_SCRIPT" "$CLEAN_DIR" >"$WORKDIR/clean-out.txt" 2>&1; then
  common_test_pass "lint exited 0 for a write routed through state-write.sh"
else
  common_test_fail "lint exited non-zero for a state-write.sh call (unexpected):
$(cat "$WORKDIR/clean-out.txt")"
fi

# =====================================================================
# Case 3 (structural control): bare `mv` file relocation, not a staged write -> exit 0
# The vault-restore shape moves a whole state file into place; it is not a jq-staged
# read-modify-write and must not be flagged on shape alone.
# =====================================================================
common_test_info "=== control case: bare mv file relocation ==="

RELOCATE_DIR="$WORKDIR/relocate"
mkdir -p "$RELOCATE_DIR"
cat > "$RELOCATE_DIR/synthetic-relocate.sh" << 'EOF'
#!/usr/bin/env bash
# Synthetic relocation fixture: restores an archived state file into place.
mv "${vault_path}/archive/state.json" "${vault_path}/state.json"
EOF

if bash "$LINT_SCRIPT" "$RELOCATE_DIR" >"$WORKDIR/relocate-out.txt" 2>&1; then
  common_test_pass "lint exited 0 for a bare mv file relocation (correctly not flagged)"
else
  common_test_fail "lint flagged a bare mv file relocation (should be exempt by shape):
$(cat "$WORKDIR/relocate-out.txt")"
fi

# =====================================================================
# Case 4 (structural control): read-only existence check redirecting to /dev/null -> exit 0
# =====================================================================
common_test_info "=== control case: read-only /dev/null check ==="

READONLY_DIR="$WORKDIR/readonly"
mkdir -p "$READONLY_DIR"
cat > "$READONLY_DIR/synthetic-readonly.sh" << 'EOF'
#!/usr/bin/env bash
# Synthetic read-only fixture: existence check, writes nothing.
if ! jq -e '.active_projects[0]' specs/state.json > /dev/null 2>&1; then
  echo "absent"
fi
EOF

if bash "$LINT_SCRIPT" "$READONLY_DIR" >"$WORKDIR/readonly-out.txt" 2>&1; then
  common_test_pass "lint exited 0 for a read-only /dev/null existence check"
else
  common_test_fail "lint flagged a read-only /dev/null existence check (should be exempt by shape):
$(cat "$WORKDIR/readonly-out.txt")"
fi

# =====================================================================
# Case 5: --verbose reports exempt candidate lines, tagged as exempt
# =====================================================================
common_test_info "=== verbose case: exempt lines are reported and tagged ==="

if bash "$LINT_SCRIPT" --verbose "$RELOCATE_DIR" 2>&1 | grep -q "\[EXEMPT\]"; then
  common_test_pass "--verbose tags exempt candidate lines"
else
  common_test_fail "--verbose did not report the exempt candidate line"
fi

# =====================================================================
# Case 6: --quiet suppresses the all-clear summary but still prints violations
# =====================================================================
common_test_info "=== quiet case: silent when clean, loud when dirty ==="

quiet_clean_out="$(bash "$LINT_SCRIPT" --quiet "$CLEAN_DIR" 2>&1)"
if [[ -z "$quiet_clean_out" ]]; then
  common_test_pass "--quiet produces no output on a clean scan"
else
  common_test_fail "--quiet produced output on a clean scan:
$quiet_clean_out"
fi

quiet_dirty_out="$(bash "$LINT_SCRIPT" --quiet "$DIRTY_DIR" 2>&1 || true)"
if grep -q "VIOLATION" <<< "$quiet_dirty_out"; then
  common_test_pass "--quiet still prints violations on a dirty scan"
else
  common_test_fail "--quiet suppressed a violation:
$quiet_dirty_out"
fi

# =====================================================================
# Case 7 (negative polarity): Python json.dump via open() with default ensure_ascii on a
# state.json target -> flagged. This is the originating incident's shape: json.dump's own write
# happens through the already-open file object, so only the open() line carries the target path.
# =====================================================================
common_test_info "=== negative case: json.dump via open() on state.json, default ensure_ascii ==="

PY_DIR="$WORKDIR/py-default"
mkdir -p "$PY_DIR"
PY_FIXTURE="$PY_DIR/synthetic-py-default.sh"
cat > "$PY_FIXTURE" << 'EOF'
#!/usr/bin/env bash
python3 -c "
import json
data = json.load(open('specs/state.json'))
data['active_projects'][0]['file_scope'].append('new_file.py')
json.dump(data, open('specs/state.json', 'w'))
"
EOF

if bash "$LINT_SCRIPT" "$PY_DIR" >"$WORKDIR/py-default-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for a default-ensure_ascii json.dump write via open() on state.json (expected non-zero)"
else
  common_test_pass "lint exited non-zero for a default-ensure_ascii json.dump write via open() on state.json"
fi

if grep -q "synthetic-py-default.sh:6" "$WORKDIR/py-default-out.txt"; then
  common_test_pass "lint reports the Python violation with file:line"
else
  common_test_fail "lint output did not name the violating file:line:
$(cat "$WORKDIR/py-default-out.txt")"
fi

# =====================================================================
# Case 8 (negative polarity): explicit ensure_ascii=False against a state.json target is ALSO
# flagged -- ensure_ascii fixes only the escaping half of the hazard, not the unsynchronized
# read-modify-write half, so this lint must not treat ensure_ascii=False as a clean bill.
# =====================================================================
common_test_info "=== negative case: json.dump with ensure_ascii=False on state.json (still flagged) ==="

PY_EA_DIR="$WORKDIR/py-ensure-ascii-false"
mkdir -p "$PY_EA_DIR"
PY_EA_FIXTURE="$PY_EA_DIR/synthetic-py-ensure-ascii-false.sh"
cat > "$PY_EA_FIXTURE" << 'EOF'
#!/usr/bin/env bash
python3 -c "
import json
data = json.load(open('specs/state.json'))
json.dump(data, open('specs/state.json', 'w'), ensure_ascii=False)
"
EOF

if bash "$LINT_SCRIPT" "$PY_EA_DIR" >"$WORKDIR/py-ea-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for an ensure_ascii=False json.dump write via open() on state.json (expected non-zero -- ensure_ascii does not fix the unsynchronized-write half of the hazard)"
else
  common_test_pass "lint exited non-zero for an ensure_ascii=False json.dump write via open() on state.json"
fi

if grep -q "synthetic-py-ensure-ascii-false.sh:5" "$WORKDIR/py-ea-out.txt"; then
  common_test_pass "lint reports the ensure_ascii=False violation with file:line"
else
  common_test_fail "lint output did not name the violating file:line:
$(cat "$WORKDIR/py-ea-out.txt")"
fi

# =====================================================================
# Case 9 (negative polarity): the two-line `with open(path, 'w') as f:` / `json.dump(obj, f)`
# idiom -- the open() line itself is flagged. The second line (`json.dump(obj, f)`) carries
# neither an `open(` token nor a mode literal and is covered by the lint's documented cross-line
# limitation, NOT by this check -- it is not separately asserted here.
# =====================================================================
common_test_info "=== negative case: two-line with-open idiom, open() line flagged ==="

PY_WITH_DIR="$WORKDIR/py-with-idiom"
mkdir -p "$PY_WITH_DIR"
PY_WITH_FIXTURE="$PY_WITH_DIR/synthetic-py-with-idiom.sh"
cat > "$PY_WITH_FIXTURE" << 'EOF'
#!/usr/bin/env bash
python3 -c "
import json
data = {'foo': 'bar'}
with open('specs/state.json', 'w') as f:
    json.dump(data, f)
"
EOF

if bash "$LINT_SCRIPT" "$PY_WITH_DIR" >"$WORKDIR/py-with-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for the two-line with-open idiom's open() line (expected non-zero)"
else
  common_test_pass "lint exited non-zero for the two-line with-open idiom's open() line"
fi

if grep -q "synthetic-py-with-idiom.sh:5" "$WORKDIR/py-with-out.txt"; then
  common_test_pass "lint reports the with-open idiom violation with file:line (the open() line, not the json.dump line)"
else
  common_test_fail "lint output did not name the violating file:line:
$(cat "$WORKDIR/py-with-out.txt")"
fi

# =====================================================================
# Case 10 (negative polarity): archive and vault-root targets are flagged via the same
# state.json substring test the jq-shaped limbs already use -- no path-prefix special-casing.
# =====================================================================
common_test_info "=== negative case: archive target, write-capable append mode ==="

PY_ARCHIVE_DIR="$WORKDIR/py-archive"
mkdir -p "$PY_ARCHIVE_DIR"
PY_ARCHIVE_FIXTURE="$PY_ARCHIVE_DIR/synthetic-py-archive.sh"
cat > "$PY_ARCHIVE_FIXTURE" << 'EOF'
#!/usr/bin/env bash
python3 -c "
import json
with open('specs/archive/state.json', 'a') as f:
    json.dump({'x': 1}, f)
"
EOF

if bash "$LINT_SCRIPT" "$PY_ARCHIVE_DIR" >"$WORKDIR/py-archive-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for a write-capable open() on the archive state.json target (expected non-zero)"
else
  common_test_pass "lint exited non-zero for a write-capable open() on the archive state.json target"
fi

common_test_info "=== negative case: vault-root target, in-place r+ rewrite mode ==="

PY_VAULT_DIR="$WORKDIR/py-vault"
mkdir -p "$PY_VAULT_DIR"
PY_VAULT_FIXTURE="$PY_VAULT_DIR/synthetic-py-vault.sh"
cat > "$PY_VAULT_FIXTURE" << 'EOF'
#!/usr/bin/env bash
python3 -c "
import json
with open(f'{vault_root}/state.json', 'r+') as f:
    data = json.load(f)
    f.seek(0)
    json.dump(data, f)
"
EOF

if bash "$LINT_SCRIPT" "$PY_VAULT_DIR" >"$WORKDIR/py-vault-out.txt" 2>&1; then
  common_test_fail "lint exited 0 for an in-place r+ open() on the vault-root state.json target (expected non-zero)"
else
  common_test_pass "lint exited non-zero for an in-place r+ open() on the vault-root state.json target"
fi

# =====================================================================
# Case 11 (structural control): a read-only Python open() on state.json -- no mode, and
# explicit 'r' -- is NOT flagged. --verbose asserts the EXEMPT reason text, so a future
# regression to "flag everything" is visible rather than silently passing.
# =====================================================================
common_test_info "=== control case: read-only Python open() (no mode) ==="

PY_RO_NOMODE_DIR="$WORKDIR/py-readonly-nomode"
mkdir -p "$PY_RO_NOMODE_DIR"
cat > "$PY_RO_NOMODE_DIR/synthetic-py-ro-nomode.sh" << 'EOF'
#!/usr/bin/env bash
python3 -c "
import json
with open('specs/state.json') as f:
    data = json.load(f)
"
EOF

if bash "$LINT_SCRIPT" "$PY_RO_NOMODE_DIR" >"$WORKDIR/py-ro-nomode-out.txt" 2>&1; then
  common_test_pass "lint exited 0 for a no-mode (default read) Python open() on state.json"
else
  common_test_fail "lint flagged a no-mode read-only Python open() (should be exempt):
$(cat "$WORKDIR/py-ro-nomode-out.txt")"
fi

if bash "$LINT_SCRIPT" --verbose "$PY_RO_NOMODE_DIR" 2>&1 | grep -q "read-only open()"; then
  common_test_pass "--verbose names the read-only-open EXEMPT reason for the no-mode case"
else
  common_test_fail "--verbose did not name the read-only-open EXEMPT reason for the no-mode case"
fi

common_test_info "=== control case: read-only Python open() (explicit 'r') ==="

PY_RO_RMODE_DIR="$WORKDIR/py-readonly-rmode"
mkdir -p "$PY_RO_RMODE_DIR"
cat > "$PY_RO_RMODE_DIR/synthetic-py-ro-rmode.sh" << 'EOF'
#!/usr/bin/env bash
python3 -c "
import json
with open('specs/state.json', 'r') as f:
    data = json.load(f)
"
EOF

if bash "$LINT_SCRIPT" "$PY_RO_RMODE_DIR" >"$WORKDIR/py-ro-rmode-out.txt" 2>&1; then
  common_test_pass "lint exited 0 for an explicit 'r' Python open() on state.json"
else
  common_test_fail "lint flagged an explicit 'r' read-only Python open() (should be exempt):
$(cat "$WORKDIR/py-ro-rmode-out.txt")"
fi

if bash "$LINT_SCRIPT" --verbose "$PY_RO_RMODE_DIR" 2>&1 | grep -q "read-only open()"; then
  common_test_pass "--verbose names the read-only-open EXEMPT reason for the explicit 'r' case"
else
  common_test_fail "--verbose did not name the read-only-open EXEMPT reason for the explicit 'r' case"
fi

# =====================================================================
# Case 12 (structural control): the lint run directly against the REAL literature-extension
# Python JSON writer scripts (not synthetic copies) exits 0. The set is enumerated at run time
# (per the plan's Scope Hypothesis) rather than hardcoded, so this case covers whatever the live
# tree actually contains rather than an assumed fixed list of three names.
# =====================================================================
common_test_info "=== control case: real literature-extension Python JSON writers ==="

LIT_DIR="$REPO_ROOT/agent-system/extensions/literature"
if [[ -d "$LIT_DIR" ]]; then
  # Enumerate via `git grep` over TRACKED files only, not a plain recursive grep. The
  # literature extension bootstraps a local venv under scripts/literature-pyenv/ for its own
  # tooling (gitignored -- see agent-system/.gitignore); a plain `grep -rl` over the directory
  # would sweep in every vendored third-party package's own json.dump/json.dumps call (pymupdf,
  # networkx, onnxruntime, ...), which is neither part of this source tree nor what "the
  # literature extension's own Python JSON writers" means, and would make this control case's
  # file set depend on whether that environment-local venv happens to exist. `git grep` reports
  # only files git actually tracks, matching the research measurement's intent.
  mapfile -t LIT_JSON_WRITERS < <(git -C "$REPO_ROOT" grep -l -E 'json\.dump|json\.dumps' -- \
    'agent-system/extensions/literature' 2>/dev/null | sed "s#^#$REPO_ROOT/#")
  if [[ "${#LIT_JSON_WRITERS[@]}" -eq 0 ]]; then
    common_test_fail "found zero literature-extension Python JSON writers -- the enumeration itself is broken, not merely empty"
  else
    common_test_info "enumerated ${#LIT_JSON_WRITERS[@]} literature-extension Python JSON writer(s): ${LIT_JSON_WRITERS[*]}"
    if bash "$LINT_SCRIPT" "${LIT_JSON_WRITERS[@]}" >"$WORKDIR/lit-real-out.txt" 2>&1; then
      common_test_pass "lint exited 0 against all real literature-extension Python JSON writers"
    else
      common_test_fail "lint flagged a real literature-extension Python JSON writer (should be exempt by content):
$(cat "$WORKDIR/lit-real-out.txt")"
    fi
  fi
else
  common_test_info "literature extension not present in this checkout -- skipping real-path control case"
fi

# =====================================================================
# Case 13: Corruption reproduction fixture. Evidences the remedy message's whole-file-diff claim
# by actually EXECUTING a default-ensure_ascii json.dump round-trip over a scratch state file
# carrying non-ASCII content (an em dash and an arrow) in rows OTHER than the one intentionally
# modified, and showing the diff touches those untouched rows too -- not merely asserting the
# claim in prose. The complementary transform (jq with --arg, mirroring state-write.sh's own
# jq-filter-plus-bindings mechanism) is also run and shown to leave the untouched rows
# byte-identical, demonstrating the remedy as well as the hazard. Entirely scoped to $WORKDIR;
# never reads or writes the real specs/state.json.
# =====================================================================
common_test_info "=== reproduction case: default-ensure_ascii round-trip produces a whole-file diff ==="

REPRO_DIR="$WORKDIR/repro"
mkdir -p "$REPRO_DIR"
REPRO_ORIGINAL="$REPRO_DIR/scratch-state.json"
REPRO_BAD="$REPRO_DIR/scratch-state-bad.json"
REPRO_GOOD="$REPRO_DIR/scratch-state-good.json"

# Three synthetic project entries. Projects 1 and 2 carry real (non-escaped) non-ASCII bytes --
# an em dash and a right arrow -- in their title field, which is NOT the field either transform
# below modifies. Project 3's file_scope is the one field both transforms intentionally change.
cat > "$REPRO_ORIGINAL" << 'EOF'
{
  "active_projects": [
    {
      "task_number": 1,
      "title": "Alpha task — em dash in title",
      "file_scope": [
        "a.sh"
      ]
    },
    {
      "task_number": 2,
      "title": "Beta task → arrow in title",
      "file_scope": [
        "b.sh"
      ]
    },
    {
      "task_number": 3,
      "title": "Gamma task, the one to be modified",
      "file_scope": [
        "c.sh"
      ]
    }
  ]
}
EOF

# The hazard: json.load + append + json.dump with default ensure_ascii (True, since it is not
# passed at all) -- exactly the originating incident's shape.
python3 -c "
import json
with open('$REPRO_ORIGINAL') as f:
    data = json.load(f)
for proj in data['active_projects']:
    if proj['task_number'] == 3:
        proj['file_scope'].append('new_file.py')
with open('$REPRO_BAD', 'w') as f:
    json.dump(data, f, indent=2)
"

# The remedy: the same append via a jq filter plus a bound argument (--arg, since the appended
# value is a string -- the same bindings mechanism state-write.sh exposes as --arg/--argjson).
jq --arg new_file "new_file.py" \
  '(.active_projects[] | select(.task_number == 3) | .file_scope) += [$new_file]' \
  "$REPRO_ORIGINAL" > "$REPRO_GOOD"

BAD_DIFF="$(diff "$REPRO_ORIGINAL" "$REPRO_BAD" || true)"
GOOD_DIFF="$(diff "$REPRO_ORIGINAL" "$REPRO_GOOD" || true)"

# Hazard assertions -----------------------------------------------------------------------
if grep -q '"title"' <<< "$BAD_DIFF"; then
  common_test_pass "default-ensure_ascii round-trip diff touches an untouched project's title field (whole-file diff, not scoped to the one changed row)"
else
  common_test_fail "default-ensure_ascii round-trip diff did NOT touch any title field -- reproduction fixture failed to demonstrate the hazard:
$BAD_DIFF"
fi

if ! grep -q $'\xe2\x80\x94' "$REPRO_BAD" && grep -q '\\u2014' "$REPRO_BAD"; then
  common_test_pass "default-ensure_ascii round-trip re-escapes the untouched em-dash byte to \\u2014"
else
  common_test_fail "default-ensure_ascii round-trip did not re-escape the em dash as expected"
fi

if ! grep -q $'\xe2\x86\x92' "$REPRO_BAD" && grep -q '\\u2192' "$REPRO_BAD"; then
  common_test_pass "default-ensure_ascii round-trip re-escapes the untouched arrow byte to \\u2192"
else
  common_test_fail "default-ensure_ascii round-trip did not re-escape the arrow as expected"
fi

if grep -q "new_file.py" "$REPRO_BAD"; then
  common_test_pass "default-ensure_ascii round-trip still carries the intentional file_scope append"
else
  common_test_fail "default-ensure_ascii round-trip lost the intentional file_scope append"
fi

# Remedy assertions -------------------------------------------------------------------------
if ! grep -q '"title"' <<< "$GOOD_DIFF"; then
  common_test_pass "jq --arg transform's diff leaves untouched projects' title fields byte-identical (the remedy, not just the hazard)"
else
  common_test_fail "jq --arg transform's diff unexpectedly touched a title field:
$GOOD_DIFF"
fi

if grep -q $'\xe2\x80\x94' "$REPRO_GOOD" && grep -q $'\xe2\x86\x92' "$REPRO_GOOD"; then
  common_test_pass "jq --arg transform leaves the untouched em-dash and arrow bytes unescaped"
else
  common_test_fail "jq --arg transform unexpectedly altered the untouched non-ASCII bytes"
fi

if grep -q "new_file.py" "$REPRO_GOOD"; then
  common_test_pass "jq --arg transform carries the intentional file_scope append"
else
  common_test_fail "jq --arg transform lost the intentional file_scope append"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
