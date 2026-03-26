# Implementation Plan: Persist Metadata in Extension Source index-entries.json Files

**Task**: 305
**Date**: 2026-03-26
**Status**: Ready

## Overview

Add missing domain, subdomain, and summary metadata to 11 extension source `index-entries.json` files so metadata persists across loader reloads.

## Phase 1: Add domain/subdomain [MECHANICAL]

For each of 11 extensions (filetypes, formal, founder, latex, lean, memory, nix, python, typst, web, z3), use jq to add:
- `"domain": "project"` to all entries missing it
- `"subdomain"` derived from second path component (e.g., `project/typst/...` -> `"typst"`)
- Special case: `project/lean4/...` -> subdomain `"lean"` (existing convention)
- Special case: entries with paths like `project/logic/...`, `project/math/...`, `project/physics/...` in formal extension -> subdomain matches path component

**Entries affected**: 186 across 11 extensions

## Phase 2: Add summaries [REQUIRES FILE READING]

For entries missing summary:
1. Check if entry has existing `description` field that meets summary conventions (27-112 chars, noun-phrase style, no trailing period)
2. If description is suitable, copy to `summary` field
3. If no suitable description, read the referenced context file and generate appropriate summary

**Entries affected**: 119 across 11 extensions

### Extensions with `description` but no `summary` (can copy):
- filetypes (7 entries) - descriptions look suitable
- latex (10 entries) - descriptions look suitable
- lean (26 entries) - descriptions look suitable
- memory (5 entries) - descriptions look suitable
- nix (11 entries) - descriptions look suitable
- python (6 entries) - descriptions look suitable
- typst (26 entries) - descriptions look suitable
- web (23 entries) - descriptions look suitable
- z3 (5 entries) - descriptions look suitable

### Extensions already having summary:
- formal (45 entries) - already has summary field
- founder (22 entries) - already has summary field

**Net**: All 119 entries missing summary already have a `description` field that can serve as the summary value.

## Phase 3: Validation

Count entries missing domain/subdomain/summary across all extensions. Expected: 0.

## Formatting

- 2-space JSON indent
- Preserve existing field order where possible
- Add domain/subdomain after path field
