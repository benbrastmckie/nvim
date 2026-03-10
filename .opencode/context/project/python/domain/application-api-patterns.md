# Application API Patterns

Standard patterns for structuring Python application APIs.

## Package Structure

```
project/src/package_name/
├── __init__.py             # Main package entry point
├── core/                   # Core domain logic
│   ├── __init__.py
│   ├── models.py           # Domain models
│   └── services.py         # Business logic
├── api/                    # External API
│   ├── __init__.py
│   ├── handlers.py         # Request handlers
│   └── serializers.py      # Data transformation
├── utils/                  # Utility functions
│   ├── __init__.py
│   └── helpers.py          # Helper functions
└── config/                 # Configuration
    ├── __init__.py
    └── settings.py         # Settings management
```

## Key Classes Pattern

### Base Classes

Use base classes to define common interfaces:

```python
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, TYPE_CHECKING

if TYPE_CHECKING:
    from .protocols import ConfigProtocol


class BaseModel(ABC):
    """Base class for domain models."""

    DEFAULT_SETTINGS = {
        'option1': True,
        'option2': 10,
        'timeout': 30,
    }

    def __init__(self, settings: Dict[str, Any], name: str = "default"):
        self.settings = {**self.DEFAULT_SETTINGS, **settings}
        self.name = name
        self._initialize_components()

    @abstractmethod
    def _initialize_components(self):
        """Initialize model-specific components."""
        pass


class BaseService(ABC):
    """Base class for services."""

    def __init__(self, model: BaseModel, config: "ConfigProtocol"):
        self.model = model
        self.config = config

    @abstractmethod
    def execute(self, *args, **kwargs) -> Any:
        """Execute the service operation."""
        pass
```

### Handler Pattern

Handlers process specific operations:

```python
class OperationHandler:
    """Handles a specific operation type."""

    def __init__(self, service: BaseService):
        self.service = service

    def handle(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process input and return result."""
        validated = self._validate(input_data)
        result = self.service.execute(validated)
        return self._format_result(result)

    def _validate(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Validate input data."""
        # Validation logic
        return data

    def _format_result(self, result: Any) -> Dict[str, Any]:
        """Format result for output."""
        return {"status": "success", "data": result}
```

## Import Patterns

Use relative imports within packages:

```python
# Within core/
from .models import BaseModel
from .services import BaseService
from ..utils import helper_function

# From package root
from package_name.core.models import BaseModel
from package_name.utils import ForAll, Exists
```

## Configuration Management

### Settings Pattern

```python
from dataclasses import dataclass
from typing import Optional
import os


@dataclass
class Settings:
    """Application settings."""

    debug: bool = False
    timeout: int = 30
    max_retries: int = 3

    @classmethod
    def from_env(cls) -> "Settings":
        """Create settings from environment variables."""
        return cls(
            debug=os.getenv("DEBUG", "false").lower() == "true",
            timeout=int(os.getenv("TIMEOUT", "30")),
            max_retries=int(os.getenv("MAX_RETRIES", "3")),
        )


# Settings dictionary pattern
DEFAULT_SETTINGS = {
    'debug': False,
    'timeout': 30,
    'max_retries': 3,
    'feature_flags': {
        'new_feature': False,
    }
}
```

### Settings Validation

```python
def validate_settings(settings: Dict[str, Any]) -> Dict[str, Any]:
    """Validate and normalize settings."""
    validated = {**DEFAULT_SETTINGS}

    for key, value in settings.items():
        if key in validated:
            validated[key] = value
        else:
            raise ValueError(f"Unknown setting: {key}")

    # Type validation
    if not isinstance(validated['timeout'], int):
        raise TypeError("timeout must be an integer")

    return validated
```

## Registry Pattern

For extensible component systems:

```python
class OperatorRegistry:
    """Registry for operator handlers."""

    def __init__(self):
        self._handlers: Dict[str, Callable] = {}

    def register(self, name: str, handler: Callable) -> None:
        """Register a handler for an operator."""
        if name in self._handlers:
            raise ValueError(f"Handler already registered: {name}")
        self._handlers[name] = handler

    def get(self, name: str) -> Callable:
        """Get handler for operator."""
        if name not in self._handlers:
            raise KeyError(f"Unknown operator: {name}")
        return self._handlers[name]

    def __contains__(self, name: str) -> bool:
        return name in self._handlers
```

## Testing Infrastructure

Tests organized alongside packages:

```
package_name/
├── core/
│   ├── models.py
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py          # Pytest fixtures
│       ├── unit/
│       │   └── test_models.py
│       └── integration/
│           └── test_full_flow.py
```

Run tests:
```bash
PYTHONPATH=src pytest src/package_name/core/tests/ -v
```

## Type Hints

Use TYPE_CHECKING for forward references:

```python
from typing import Dict, Any, Optional, Set, Tuple, Union, List, TYPE_CHECKING

if TYPE_CHECKING:
    from .protocols import ServiceProtocol, StateType
    from package_name.core import Model
```

## Protocols

Type protocols for duck typing:

```python
from typing import Protocol, runtime_checkable


@runtime_checkable
class ServiceProtocol(Protocol):
    """Interface for service classes."""

    def execute(self, *args, **kwargs) -> Any:
        """Execute the service operation."""
        ...

    @property
    def is_ready(self) -> bool:
        """Check if service is ready."""
        ...


class RegistryProtocol(Protocol):
    """Interface for registries."""

    def register(self, name: str, handler: Any) -> None:
        ...

    def get(self, name: str) -> Any:
        ...
```

## Error Handling

### Custom Exceptions

```python
class ApplicationError(Exception):
    """Base exception for application errors."""
    pass


class ValidationError(ApplicationError):
    """Raised when validation fails."""

    def __init__(self, message: str, field: Optional[str] = None):
        self.message = message
        self.field = field
        super().__init__(message)


class ConfigurationError(ApplicationError):
    """Raised when configuration is invalid."""
    pass
```

### Error Handler Pattern

```python
def handle_errors(func):
    """Decorator for standardized error handling."""
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except ValidationError as e:
            return {"status": "error", "type": "validation", "message": str(e)}
        except ApplicationError as e:
            return {"status": "error", "type": "application", "message": str(e)}
        except Exception as e:
            logging.exception("Unexpected error")
            return {"status": "error", "type": "internal", "message": "Internal error"}
    return wrapper
```
