#!/usr/bin/env bash
# sweep-skeletons.sh - machine-check every agent-system/extensions/*/agents/*.md embedded
# report/summary skeleton against validate-artifact.sh's own REPORT_SECTIONS/SUMMARY_SECTIONS
# arrays and its own `^##+ {section}` regex.
#
# Usage: sweep-skeletons.sh [glob]
#   With no argument, scans agent-system/extensions/*/agents/*.md (repo-root-relative).
#   With an argument, scans that glob instead (e.g. a formal-only re-run).
#
# Extraction uses a line-based fence parser (tracks fence open/close state per line) rather
# than a single regex pass, because a naive regex mis-pairs fences whenever a language-tagged
# opening fence appears before the true bare closing fence is reached in scan order.
#
# Exit codes: 0 = harness ran and printed its verdicts; 1 = zero agent-system/extensions/formal/
# agents/*.md files were found (the harness invocation itself is broken, checked BEFORE any
# formal-agent verdict is reported); 5 = could not read REPORT_SECTIONS/SUMMARY_SECTIONS out of
# validate-artifact.sh.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/agent-system/extensions/core/scripts/validate-artifact.sh"
GLOB_ARG="${1:-agent-system/extensions/*/agents/*.md}"

if [ ! -f "$VALIDATOR" ]; then
  echo "[FAIL] validator not found at $VALIDATOR" >&2
  exit 5
fi

python3 -I - "$REPO_ROOT" "$VALIDATOR" "$GLOB_ARG" <<'PYEOF'
import sys, re, glob, os

repo_root, validator_path, pattern = sys.argv[1], sys.argv[2], sys.argv[3]

def read_array(validator_path, name):
    with open(validator_path, encoding="utf-8") as fh:
        text = fh.read()
    m = re.search(rf'^{name}=\((.*?)\)', text, re.MULTILINE)
    if not m:
        print(f"[FAIL] could not read {name} out of {validator_path}", file=sys.stderr)
        sys.exit(5)
    return re.findall(r'"([^"]*)"', m.group(1))

report_sections = read_array(validator_path, "REPORT_SECTIONS")
summary_sections = read_array(validator_path, "SUMMARY_SECTIONS")

def extract_blocks(path):
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()
    blocks = []
    in_fence = False
    current = []
    fence_re = re.compile(r'^\s*```')
    for line in lines:
        if fence_re.match(line):
            if in_fence:
                blocks.append(current)
                current = []
                in_fence = False
            else:
                in_fence = True
                current = []
            continue
        if in_fence:
            current.append(line)
    return blocks

def classify(block):
    first_nonblank = next((l for l in block if l.strip()), "")
    stripped = first_nonblank.strip()
    if re.match(r'^#\s+.*Report', stripped):
        return "report"
    if re.match(r'^#\s+.*Summary', stripped):
        return "summary"
    return None

def missing_sections(block, kind):
    text = "".join(block)
    sections = report_sections if kind == "report" else summary_sections
    return [s for s in sections if not re.search(rf'^##+ {re.escape(s)}', text, re.MULTILINE)]

if not os.path.isabs(pattern):
    pattern = os.path.join(repo_root, pattern)

files = sorted(glob.glob(pattern))

formal_count = sum(1 for f in files if "/formal/" in os.path.relpath(f, repo_root))
if formal_count == 0:
    print(
        "[FAIL] zero agent-system/extensions/formal/agents/*.md files found -- "
        "harness invocation is broken",
        file=sys.stderr,
    )
    sys.exit(1)

total = 0
passed = 0
failed = 0
skeletonless = 0

for f in files:
    rel = os.path.relpath(f, repo_root)
    blocks = extract_blocks(f)
    skeleton_blocks = [(classify(b), b) for b in blocks]
    skeleton_blocks = [(k, b) for k, b in skeleton_blocks if k is not None]
    if not skeleton_blocks:
        skeletonless += 1
        print(f"[SKELETON-LESS] {rel}")
        continue
    total += 1
    file_kind = skeleton_blocks[0][0]
    problems = []
    for kind, block in skeleton_blocks:
        missing = missing_sections(block, kind)
        if missing:
            problems.append(f"{kind}: missing {', '.join(missing)}")
    if problems:
        failed += 1
        print(f"[FAIL] {rel} ({file_kind}): {'; '.join(problems)}")
    else:
        passed += 1
        print(f"[PASS] {rel} ({file_kind})")

print()
print(
    f"Summary: {len(files)} agent file(s) scanned, {total} with an embedded skeleton "
    f"({passed} PASS, {failed} FAIL), {skeletonless} skeleton-less, "
    f"{formal_count} under extensions/formal/"
)
sys.exit(0)
PYEOF
