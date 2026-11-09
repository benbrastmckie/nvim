# Python Extension

Python development support with pytest integration, type checking (mypy), and linting/formatting (ruff).

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `python` | python-research-agent | Python/library research |
| `python` | python-implementation-agent | Python implementation |

## Installation

Loaded via the extension picker. Once loaded, `python` becomes a recognized task type.

## Commands

No dedicated commands. Use the core research, plan, and implement phases (dispatched via `/orchestrate`) with `task_type: "python"`.

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-python-research | python-research-agent | Python/library research |
| skill-python-implementation | python-implementation-agent | Python implementation |

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `python` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash(python, pytest) |

## Testing

```bash
pytest                                    # Run all tests
pytest path/to/test.py::test_function     # Run specific test
pytest --cov=src                          # With coverage
pytest-watch                              # Watch mode
```

## Code Quality

```bash
mypy src/                # Type checking
ruff check src/          # Linting
ruff format src/         # Formatting
make lint                # All checks (if Makefile provided)
nox -s lint              # Via nox session
```

The implementation agent runs `pytest`, `mypy`, and `ruff check` after each phase of edits and blocks on failures.

## References

- [Python docs](https://docs.python.org/3/)
- [pytest](https://docs.pytest.org/)
- [mypy](https://mypy.readthedocs.io/)
- [ruff](https://docs.astral.sh/ruff/)
