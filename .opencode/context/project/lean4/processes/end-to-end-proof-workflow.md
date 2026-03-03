# End-to-End Proof Workflow

## Overview
This file outlines the standard workflow for developing a proof in LEAN 4, from stating the theorem to finalizing the proof.

## When to Use
- When starting a new proof.
- When reviewing an existing proof.

## Prerequisites
- A clear statement of the theorem to be proven.
- A good understanding of the relevant mathematical concepts.

## Process Steps

### Step 1: State the Theorem
**Action**: Write the theorem statement in LEAN 4 syntax.
**Validation**: The theorem statement should be well-formed and type-check.
**Output**: A theorem statement with a `sorry` proof.

### Step 2: Outline the Proof
**Action**: Write a high-level outline of the proof in comments.
**Validation**: The outline should be a valid argument for the theorem.
**Output**: A commented proof outline.

### Step 3: Fill in the Proof
**Action**: Fill in the proof using tactics and term-mode proofs.
**Validation**: The proof should be complete and type-check.
**Output**: A complete proof.

### Step 4: Refactor the Proof
**Action**: Refactor the proof to improve readability and maintainability.
**Validation**: The refactored proof should be more concise and easier to understand.
**Output**: A clean and readable proof.

## Context Dependencies
- `lean4-syntax.md`
- `mathlib-overview.md`
- `key-mathematical-concepts.md`

## Success Criteria
- The proof is complete and correct.
- The proof is readable and maintainable.
