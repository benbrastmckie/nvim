#!/usr/bin/env bash
# task-ref-ok:begin test fixture: every "task N" string below is a synthetic project_number
# literal (10, 11, 20, 21, 30, 40, 50, 60, 99998, 99999) fed to the lint under test as fake
# fixture data, or that lint's own echoed output text quoting one back -- never a citation of a
# real task in this system's own backlog. Category-6 analog (test fixtures for the thing under
# test need concrete digits; a placeholder would not match the lint's own numeric parsing and
# would silently disable the assertion).
#
# test-lint-roadmap-batch-proposals.sh - Fixture suite for
# scripts/lint/lint-roadmap-batch-proposals.sh: one fixture per finding ((a), (c), (d), (f)),
# the two required negative cases (rejected finding (b)'s absence; finding (f)'s two
# false-positive classes), the unknown/stage layout cases, and the advisory exit-code contract.
#
# Structural model: test-lint-json-channel-discipline.sh's resolve-subject helper call
# (mode=deploy-tree-first) and WORKDIR-fixture conventions. Class B strict mode (`set -uo
# pipefail`, no `-e`): this suite accumulates a PASSED/FAILED counter across many independent
# cases and must keep going past an individual case's failure to report everything that's wrong.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

LINT_SCRIPT="$(common_test_resolve_subject "lint-roadmap-batch-proposals.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-roadmap-batch-proposals.sh" \
  "$SCRIPT_DIR/../lint/lint-roadmap-batch-proposals.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0

common_test_workdir_init

run_lint() {
  # Usage: run_lint <roadmap_path> <state_path> [extra args...]
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  bash "$LINT_SCRIPT" --verbose "$@" >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

# Classic-layout fixture skeleton: the eight CLASSIC_HEADERS with a caller-supplied `## Next`
# body spliced in, so every classic-layout fixture below shares one source of truth for the
# other seven required headers rather than re-typing them per case.
write_classic_fixture() {
  # Usage: write_classic_fixture <roadmap_path> <next_body>
  local path="$1" next_body="$2"
  cat > "$path" <<EOF
## Goal

x

## Gate state

x

## Next

$next_body

## Open work

x

## Checks before and after every call

x

## Settled decisions (do not re-litigate)

x

## Standing rules

x

## Unfiled observations (none worth a task yet)

x
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Finding (a): the real observed failure -- two tasks sharing three files under one component's
# certificate/ directory, one omitted from the batch.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Finding (a): real observed failure (shared certificate/ territory, one omitted)"
write_classic_fixture "$WORKDIR/finding-a-real-failure.md" '```
/orchestrate 10
```

Why this order:

- x'
cat > "$WORKDIR/finding-a-real-failure-state.json" <<'EOF'
{"active_projects":[
  {"project_number":10,"status":"not_started","file_scope":["components/framed_channel/certificate/a.txt","components/framed_channel/certificate/b.txt","components/framed_channel/certificate/c.txt"]},
  {"project_number":11,"status":"not_started","dependencies":[10],"file_scope":["components/framed_channel/certificate/b.txt"]}
]}
EOF
run_lint --roadmap "$WORKDIR/finding-a-real-failure.md" --state "$WORKDIR/finding-a-real-failure-state.json"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(echo "$LAST_STDOUT" | grep -c 'FINDING (a)')" -eq 1 ] \
   && echo "$LAST_STDOUT" | grep -q 'task 11' && echo "$LAST_STDOUT" | grep -q 'task 10' \
   && echo "$LAST_STDOUT" | grep -q 'certificate/b.txt'; then
  common_test_pass "finding (a): real observed failure reproduces as exactly one finding, naming both tasks and the shared path"
else
  common_test_fail "finding (a): expected exactly one FINDING (a) naming tasks 10/11 and certificate/b.txt" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Finding (a) negative: an omitted DEPENDENT with no territory overlap must produce NO finding --
# this is the acceptance criterion demonstrating rejected finding (b) is genuinely absent.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Finding (a) negative: omitted dependent with no territory overlap -- rejected finding (b) stays absent"
write_classic_fixture "$WORKDIR/finding-a-dependent-no-overlap.md" '```
/orchestrate 20
```

Why this order:

- x'
cat > "$WORKDIR/finding-a-dependent-no-overlap-state.json" <<'EOF'
{"active_projects":[
  {"project_number":20,"status":"not_started","file_scope":["scripts/foo.sh"]},
  {"project_number":21,"status":"not_started","dependencies":[20],"file_scope":["scripts/bar.sh"]}
]}
EOF
run_lint --roadmap "$WORKDIR/finding-a-dependent-no-overlap.md" --state "$WORKDIR/finding-a-dependent-no-overlap-state.json"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(echo "$LAST_STDOUT" | grep -c 'FINDING')" -eq 0 ]; then
  common_test_pass "finding (a) negative: dependent with no overlap produces zero findings"
else
  common_test_fail "finding (a) negative: expected zero findings" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Finding (c): a Run line with nine ids exceeds MAX_TASKS=8. The message must not propose a
# trimmed batch -- assert no second "/orchestrate"-shaped line appears anywhere in stdout.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Finding (c): nine-task Run line exceeds MAX_TASKS=8, no trimmed batch proposed"
write_classic_fixture "$WORKDIR/finding-c.md" '```
/orchestrate 1, 2, 3, 4, 5, 6, 7, 8, 9
```

Why this order:

- x'
cat > "$WORKDIR/finding-c-state.json" <<'EOF'
{"active_projects":[
  {"project_number":1,"status":"not_started","file_scope":[]},
  {"project_number":2,"status":"not_started","file_scope":[]},
  {"project_number":3,"status":"not_started","file_scope":[]},
  {"project_number":4,"status":"not_started","file_scope":[]},
  {"project_number":5,"status":"not_started","file_scope":[]},
  {"project_number":6,"status":"not_started","file_scope":[]},
  {"project_number":7,"status":"not_started","file_scope":[]},
  {"project_number":8,"status":"not_started","file_scope":[]},
  {"project_number":9,"status":"not_started","file_scope":[]}
]}
EOF
run_lint --roadmap "$WORKDIR/finding-c.md" --state "$WORKDIR/finding-c-state.json"
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -q 'FINDING (c)' \
   && echo "$LAST_STDOUT" | grep -q 'exceeds MAX_TASKS=8' \
   && [ "$(echo "$LAST_STDOUT" | grep -cE '^/orchestrate ')" -eq 0 ]; then
  common_test_pass "finding (c): nine-task batch flagged, no trimmed batch line emitted"
else
  common_test_fail "finding (c): expected a FINDING (c) and no proposed /orchestrate line" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Finding (d): a terminal task and a nonexistent task, with distinguishable messages.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Finding (d): terminal task and nonexistent task, distinguishable messages"
write_classic_fixture "$WORKDIR/finding-d.md" '```
/orchestrate 30, 99999
```

Why this order:

- x'
cat > "$WORKDIR/finding-d-state.json" <<'EOF'
{"active_projects":[
  {"project_number":30,"status":"completed","file_scope":[]}
]}
EOF
run_lint --roadmap "$WORKDIR/finding-d.md" --state "$WORKDIR/finding-d-state.json"
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -q 'task 30 is terminal' \
   && echo "$LAST_STDOUT" | grep -q 'task 99999 does not exist'; then
  common_test_pass "finding (d): terminal and nonexistent tasks both flagged with distinguishable messages"
else
  common_test_fail "finding (d): expected distinguishable terminal/nonexistent messages" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Finding (f): a genuinely unresolvable specs/{NNN}_{slug}/... citation (the archival-move
# defect class).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Finding (f): unresolvable specs/{NNN}_{slug}/... citation"
write_classic_fixture "$WORKDIR/finding-f-unresolvable.md" '```
/orchestrate 40
```

Why this order:

- See `specs/999_moved_task/reports/01_moved-report.md` for details.'
cat > "$WORKDIR/finding-f-unresolvable-state.json" <<'EOF'
{"active_projects":[
  {"project_number":40,"status":"not_started","file_scope":[]}
]}
EOF
run_lint --roadmap "$WORKDIR/finding-f-unresolvable.md" --state "$WORKDIR/finding-f-unresolvable-state.json"
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -q 'FINDING (f)' \
   && echo "$LAST_STDOUT" | grep -q 'specs/999_moved_task/reports/01_moved-report.md'; then
  common_test_pass "finding (f): unresolvable specs/... citation flagged"
else
  common_test_fail "finding (f): expected an unresolvable-citation finding" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Finding (f) negative: one file carrying BOTH false-positive classes -- a bare backticked
# basename, and a path qualified for another repository -- must produce zero finding-(f) lines.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Finding (f) negative: bare basename + cross-repo path, both false-positive classes"
write_classic_fixture "$WORKDIR/finding-f-false-positives.md" '```
/orchestrate 50
```

Why this order:

- See `ci.yml` for the workflow, and `~/.config/nvim/specs/other-repo-file.md` for the other repo.'
cat > "$WORKDIR/finding-f-false-positives-state.json" <<'EOF'
{"active_projects":[
  {"project_number":50,"status":"not_started","file_scope":[]}
]}
EOF
run_lint --roadmap "$WORKDIR/finding-f-false-positives.md" --state "$WORKDIR/finding-f-false-positives-state.json"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(echo "$LAST_STDOUT" | grep -c 'FINDING (f)')" -eq 0 ]; then
  common_test_pass "finding (f) negative: bare basename and cross-repo path both produce zero findings"
else
  common_test_fail "finding (f) negative: expected zero FINDING (f) lines" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Unknown layout: neither classic nor stage -- the named note on stderr, exit 0, nothing parsed.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Unknown layout: named note on stderr, exit 0, not a silent clean report"
cat > "$WORKDIR/unknown-layout.md" <<'EOF'
# Not a roadmap

Just prose, no recognised section vocabulary.
EOF
cat > "$WORKDIR/unknown-layout-state.json" <<'EOF'
{"active_projects":[]}
EOF
run_lint --roadmap "$WORKDIR/unknown-layout.md" --state "$WORKDIR/unknown-layout-state.json"
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDERR" | grep -q 'NOTE: layout=unknown; no batch block parsed'; then
  common_test_pass "unknown layout: named note on stderr, exit 0"
else
  common_test_fail "unknown layout: expected the named stderr note and exit 0" "exit=$LAST_EXIT stderr=$LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Stage layout: Run lines in the run-order section are parsed, not silently skipped.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Stage layout: Run lines in the run-order section are parsed"
cat > "$WORKDIR/stage-layout.md" <<'EOF'
# Roadmap

## Stage 1 -- Decidability

Some prose.

## Run order at a glance

```
/orchestrate 60, 99998
```

Why this order:

- x
EOF
cat > "$WORKDIR/stage-layout-state.json" <<'EOF'
{"active_projects":[
  {"project_number":60,"status":"not_started","file_scope":[]}
]}
EOF
run_lint --roadmap "$WORKDIR/stage-layout.md" --state "$WORKDIR/stage-layout-state.json"
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -q 'layout=stage' \
   && echo "$LAST_STDOUT" | grep -q 'task 99998 does not exist'; then
  common_test_pass "stage layout: Run line parsed (finding (d) fires on the nonexistent id, proving the line was read)"
else
  common_test_fail "stage layout: expected layout=stage and a finding on the nonexistent id" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Advisory contract: exit code is 0 even with findings present. Pinned mechanically here (every
# case above already exercises this, but this assertion pins it explicitly against the
# finding-(c) fixture, which is guaranteed to produce at least one finding).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Advisory contract: exit code is 0 with findings present"
run_lint --roadmap "$WORKDIR/finding-c.md" --state "$WORKDIR/finding-c-state.json"
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -q 'FINDING'; then
  common_test_pass "advisory contract: exit 0 with findings present"
else
  common_test_fail "advisory contract: expected exit 0 with at least one finding present" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Real corpus: no explicit --roadmap/--state (the lint's own default resolution) against the
# real repo completes and exits 0.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Real corpus: default resolution against the real repo completes and exits 0"
run_lint
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -q 'Scan complete'; then
  common_test_pass "real corpus: default resolution completes and exits 0"
else
  common_test_fail "real corpus: expected a completed scan and exit 0" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
# task-ref-ok:end
