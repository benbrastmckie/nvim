#!/bin/bash
# migrate-directory-padding.sh - Migrate unpadded task directories to 3-digit padded format
#
# Usage:
#   ./migrate-directory-padding.sh [--dry-run] [--specs-dir DIR]
#
# Options:
#   --dry-run     Preview changes without executing them
#   --specs-dir   Override default specs directory (default: specs/)
#
# Examples:
#   ./migrate-directory-padding.sh --dry-run
#   ./migrate-directory-padding.sh
#   ./migrate-directory-padding.sh --specs-dir .claude/specs

set -euo pipefail

# Default configuration
DRY_RUN=false
SPECS_DIR="specs"
PROJECT_ROOT=""
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --specs-dir)
      SPECS_DIR="$2"
      shift 2
      ;;
    --project-root)
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--specs-dir DIR] [--project-root DIR] [--verbose]"
      echo ""
      echo "Migrate unpadded task directories to 3-digit padded format."
      echo ""
      echo "Options:"
      echo "  --dry-run       Preview changes without executing them"
      echo "  --specs-dir     Override default specs directory (default: specs/)"
      echo "  --project-root  Project root directory (default: current directory)"
      echo "  --verbose       Show detailed output"
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option: $1${NC}" >&2
      exit 1
      ;;
  esac
done

# Find project root if not specified
if [[ -z "$PROJECT_ROOT" ]]; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi

# Full path to specs directory
FULL_SPECS_DIR="$PROJECT_ROOT/$SPECS_DIR"

# Validate specs directory exists
if [[ ! -d "$FULL_SPECS_DIR" ]]; then
  echo -e "${RED}Error: Specs directory not found: $FULL_SPECS_DIR${NC}" >&2
  exit 1
fi

# Output mode
if [[ "$DRY_RUN" == "true" ]]; then
  echo -e "${YELLOW}DRY RUN MODE - no changes will be made${NC}"
  echo ""
fi

echo -e "${BLUE}Scanning: $FULL_SPECS_DIR${NC}"
echo ""

# Track statistics
DIRS_FOUND=0
DIRS_UNPADDED=0
DIRS_PADDED=0
DIRS_MIGRATED=0
ERRORS=0

# Find and process task directories
shopt -s nullglob
for dir in "$FULL_SPECS_DIR"/[0-9]*_*/; do
  if [[ ! -d "$dir" ]]; then
    continue
  fi

  DIRS_FOUND=$((DIRS_FOUND + 1))
  basename=$(basename "$dir")

  # Extract the numeric prefix
  if [[ "$basename" =~ ^([0-9]+)_(.+)$ ]]; then
    num="${BASH_REMATCH[1]}"
    slug="${BASH_REMATCH[2]}"
  else
    [[ "$VERBOSE" == "true" ]] && echo -e "${YELLOW}Skipping (no match): $basename${NC}"
    continue
  fi

  # Check if already 3-digit padded
  if [[ ${#num} -eq 3 ]]; then
    DIRS_PADDED=$((DIRS_PADDED + 1))
    [[ "$VERBOSE" == "true" ]] && echo -e "${GREEN}Already padded: $basename${NC}"
    continue
  fi

  # Check if number is greater than 999 (4+ digit padded)
  if [[ ${#num} -ge 4 ]]; then
    DIRS_PADDED=$((DIRS_PADDED + 1))
    [[ "$VERBOSE" == "true" ]] && echo -e "${GREEN}Already 4+ digit: $basename${NC}"
    continue
  fi

  # Need to migrate
  DIRS_UNPADDED=$((DIRS_UNPADDED + 1))

  # Create padded name
  padded_num=$(printf "%03d" "$num")
  new_name="${padded_num}_${slug}"
  new_path="$FULL_SPECS_DIR/$new_name"

  echo -e "Rename: ${YELLOW}$basename${NC} -> ${GREEN}$new_name${NC}"

  if [[ "$DRY_RUN" == "false" ]]; then
    # Check if target already exists
    if [[ -e "$new_path" ]]; then
      echo -e "${RED}  Error: Target already exists: $new_name${NC}" >&2
      ERRORS=$((ERRORS + 1))
      continue
    fi

    # Perform rename
    if mv "$dir" "$new_path"; then
      DIRS_MIGRATED=$((DIRS_MIGRATED + 1))
      echo -e "  ${GREEN}[OK]${NC}"
    else
      echo -e "  ${RED}[FAILED]${NC}" >&2
      ERRORS=$((ERRORS + 1))
    fi
  else
    DIRS_MIGRATED=$((DIRS_MIGRATED + 1))  # Count as would-be-migrated in dry run
  fi
done
shopt -u nullglob

# Summary
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo "Directories scanned:    $DIRS_FOUND"
echo "Already padded:         $DIRS_PADDED"
echo "Unpadded found:         $DIRS_UNPADDED"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Would migrate:          $DIRS_MIGRATED"
else
  echo "Successfully migrated:  $DIRS_MIGRATED"
fi

if [[ $ERRORS -gt 0 ]]; then
  echo -e "${RED}Errors:                 $ERRORS${NC}"
fi

# Exit status
if [[ $ERRORS -gt 0 ]]; then
  exit 1
elif [[ $DIRS_UNPADDED -eq 0 ]]; then
  echo ""
  echo -e "${GREEN}All directories already use 3-digit padding. No migration needed.${NC}"
  exit 0
else
  if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo -e "${YELLOW}Run without --dry-run to apply changes.${NC}"
  else
    echo ""
    echo -e "${GREEN}Migration complete.${NC}"
  fi
  exit 0
fi
