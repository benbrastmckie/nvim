# Python Context

This directory contains context files for Python development.

## Structure

- `domain/` - Python patterns, API references
- `patterns/` - Testing patterns, code organization
- `standards/` - Code style, conventions

## Key Files

- `standards/code-style.md` - Python coding conventions
- `patterns/testing-patterns.md` - Pytest patterns and fixtures
- `domain/python-patterns.md` - Common Python idioms

## Quick Reference

### Project Setup
```bash
python -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

### Testing
```bash
pytest                    # Run all tests
pytest -v                 # Verbose output
pytest -k "test_name"     # Run specific tests
pytest --cov=src          # With coverage
```

### Code Quality
```bash
ruff check src/           # Lint
ruff format src/          # Format
mypy src/                 # Type check
```

## For Research

Load: `domain/python-patterns.md`, `standards/code-style.md`

## For Implementation

Load: `patterns/testing-patterns.md`, `standards/code-style.md`
