# Library Patterns

Standard patterns for building domain-specific Python libraries.

## Directory Structure

Each library module follows this structure:

```
library_name/
├── __init__.py          # Package exports
├── core.py              # Main functionality class
├── operators.py         # Operator/function definitions
├── examples.py          # Example configurations
├── utils.py             # Utility functions
├── protocols.py         # Type protocols (optional)
└── tests/
    ├── __init__.py
    ├── conftest.py
    ├── unit/            # Unit tests
    └── integration/     # Integration tests
```

## Submodule Structure

Complex libraries use submodules:

```
library_name/
├── core.py              # Shared core functionality
├── operators.py         # Core operators
├── examples.py
└── submodules/
    ├── __init__.py
    ├── feature_a/
    │   ├── __init__.py
    │   ├── operators.py
    │   └── examples.py
    ├── feature_b/
    └── feature_c/
```

## Core Module Pattern

The main class inherits from a base class:

```python
"""
Core module for library functionality.
"""

from typing import Dict, Any, Optional, TYPE_CHECKING
from abc import ABC, abstractmethod

if TYPE_CHECKING:
    from .protocols import DataType


class CoreBase(ABC):
    """
    Base class for library functionality.
    """

    DEFAULT_SETTINGS = {
        'option1': True,
        'option2': 10,
        'max_time': 30,
        'mode': 'default',
    }

    def __init__(self, settings: Dict[str, Any], name: str = "default"):
        self.settings = {**self.DEFAULT_SETTINGS, **settings}
        self.name = name
        self._initialize_components()

    @abstractmethod
    def _initialize_components(self):
        """Initialize library-specific components."""
        pass


class LibraryCore(CoreBase):
    """
    Main library functionality.
    """

    def __init__(self, settings: Dict[str, Any], name: str = "library"):
        super().__init__(settings, name)
        self.registry = OperatorRegistry()

    def _initialize_components(self):
        """Initialize components."""
        self._load_operators()

    def _load_operators(self):
        """Load operator definitions."""
        from .operators import get_operators
        operators = get_operators(self)
        for name, handler in operators.items():
            self.registry.register(name, handler)
```

## Operators Module Pattern

Operators are registered via `get_operators()` function:

```python
"""
Operator definitions for the library.
"""

from typing import TYPE_CHECKING, Callable, Dict

if TYPE_CHECKING:
    from .core import LibraryCore


def get_operators(core: "LibraryCore") -> Dict[str, Callable]:
    """
    Return operator definitions.

    Args:
        core: The core instance to bind operators to

    Returns:
        Dictionary mapping operator names to handler functions
    """
    return {
        'operation1': lambda data, args: _handle_operation1(core, data, args),
        'operation2': lambda data, args: _handle_operation2(core, data, args),
        'operation3': lambda data, args: _handle_operation3(core, data, args),
    }


def _handle_operation1(core, data, args):
    """Handle operation1."""
    # Implementation
    pass


def _handle_operation2(core, data, args):
    """Handle operation2."""
    # Implementation
    pass


def _handle_operation3(core, data, args):
    """Handle operation3."""
    # Implementation
    pass
```

## Examples Module Pattern

Examples are defined via `get_examples()` function:

```python
"""
Example definitions for the library.
"""

from typing import List, Dict, Any


def get_examples() -> List[Dict[str, Any]]:
    """
    Return list of example configurations.

    Each example has:
    - 'name': Display name
    - 'input': Input data
    - 'expected': Expected result
    - 'settings': Optional override settings
    """
    return [
        {
            'name': "Basic Example",
            'input': {"a": 1, "b": 2},
            'expected': {"result": 3},
            'settings': {'mode': 'basic'},
        },
        {
            'name': "Advanced Example",
            'input': {"data": [1, 2, 3]},
            'expected': {"sum": 6, "avg": 2.0},
            'settings': {'mode': 'advanced'},
        },
    ]
```

## Package Init Pattern

Package init exports main components:

```python
"""
Library package.
"""

from .core import LibraryCore
from .operators import get_operators
from .examples import get_examples

__all__ = [
    'LibraryCore',
    'get_operators',
    'get_examples',
]
```

## Submodule Integration

Submodules extend base operators and examples:

```python
# In library_name/submodules/feature_a/__init__.py
from .operators import get_operators
from .examples import get_examples

# In library_name/__init__.py
from .submodules import feature_a, feature_b
```

Submodule operators are merged with base operators during initialization.

## Operator Registration

Operators are registered with a registry:

```python
# During initialization
from .operators import get_operators

operators = get_operators(self)
for name, handler in operators.items():
    self.registry.register(name, handler)
```

## Settings Dictionary

Standard settings keys:

| Key | Type | Description |
|-----|------|-------------|
| `mode` | str | Operating mode |
| `max_time` | int | Timeout in seconds |
| `debug` | bool | Enable debug output |
| `strict` | bool | Strict validation mode |
| `cache` | bool | Enable caching |
| `expectation` | Any/None | Expected result |

## Type Checking

Use TYPE_CHECKING for forward references:

```python
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .core import LibraryCore
    from .protocols import DataType
```

This avoids circular imports while maintaining type safety.

## Extensibility Pattern

Allow users to extend functionality:

```python
class ExtensibleCore(LibraryCore):
    """Core with extension support."""

    def register_extension(self, name: str, extension: Any) -> None:
        """Register a custom extension."""
        self.extensions[name] = extension

    def load_extension(self, name: str) -> Any:
        """Load and return an extension."""
        if name not in self.extensions:
            raise KeyError(f"Extension not found: {name}")
        return self.extensions[name]
```

## Plugin Pattern

Support for loadable plugins:

```python
import importlib
from typing import List


def load_plugins(plugin_names: List[str]) -> Dict[str, Any]:
    """Load plugins by module name."""
    plugins = {}
    for name in plugin_names:
        try:
            module = importlib.import_module(name)
            if hasattr(module, 'register'):
                plugins[name] = module.register()
        except ImportError as e:
            logging.warning(f"Could not load plugin {name}: {e}")
    return plugins
```
