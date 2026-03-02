## Python Extension

This project includes Python development support via the python extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `python` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (python, pytest) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-python-research | python-research-agent | Python/library research |
| skill-python-implementation | python-implementation-agent | Python implementation |

### Testing

- Run tests: `pytest`
- Run specific test: `pytest path/to/test.py::test_function`
- Coverage: `pytest --cov=src`
- Watch mode: `pytest-watch`

### Code Quality

- Type checking: `mypy src/`
- Linting: `ruff check src/`
- Formatting: `ruff format src/`
- All checks: `make lint` or `nox -s lint`
