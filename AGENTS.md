# AGENTS.md - Sophis Development Guide

## Build, Lint, and Test Commands

### Core Commands
```bash
flutter pub get          # Install dependencies
flutter run              # Run the app
flutter analyze          # Run static analysis (lint + type check)
flutter test             # Run all tests
```

### Single Test Execution
```bash
# Run a specific test file
flutter test test/services/food_entry_factory_test.dart

# Run tests matching a pattern
flutter test --name "FoodEntryFactory"

# Run with coverage
flutter test --coverage
```

### Code Generation (Drift/SQLite)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Build for Release
```bash
flutter build ios --release
flutter build apk --release
```

## Code Style Guidelines

### Imports
Order: `dart` → `flutter` → `packages` → `local (relative paths)`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/food_entry.dart';
import 'services/storage_service.dart';
```

### File Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Methods/variables: `camelCase`
- Private members: prefix with `_`

### Analysis Options
This project uses `flutter_lints` with additional strict rules in `analysis_options.yaml`:
- Missing required parameters: **error**
- Deprecated member usage: **warning**
- Undefined methods/properties: **error**

Key linter rules enforced:
```yaml
prefer_single_quotes: true          # Use ' not "
require_trailing_commas: true        # AlwaysTrailingCommas
use_key_in_widget_constructors: true # Use key in widget constructors
always_declare_return_types: true   # Explicit return types
prefer_const_constructors: true      # const constructors when possible
prefer_final_fields: true            # Final fields
prefer_final_locals: true            # Final locals
use_build_context_synchronously: true
```

### Types
- Always declare explicit return types on methods and functions
- Use `double` for numeric values, not `int` for measurements
- Prefer `num` for values that can be int or double
- Use sealed classes for Result types (see Error Handling below)

### Nullable Types
- Use `?` for nullable types: `String?`, `DateTime?`
- Access nullable values with `?.` or null-aware operators
- Prefer `valueOrNull` pattern over force unwrap

## Error Handling

### ServiceResult Pattern
Use the `ServiceResult<T>` sealed class for service operations:

```dart
sealed class ServiceResult<T> {
  const ServiceResult();
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  T? get valueOrNull => switch (this) { ... };
}

class Success<T> extends ServiceResult<T> { ... }
class Failure<T> extends ServiceResult<T> { ... }
```

Service errors use `ServiceErrorType` enum:
```dart
enum ServiceErrorType {
  network,
  notFound,
  rateLimited,
  parseError,
  authFailed,
  unknown,
}
```

## UI Conventions

### Settings Tiles
Use existing styled components from `lib/ui/components/settings/settings_tiles.dart`:
- `NavigationTile` - For navigation to another screen
- `SwitchTile` - For toggle settings
- `DataActionTile` - For actions with loading states

### Common Styling Values
```dart
// Container borders
Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1))
BorderRadius.circular(AppTheme.radiusMD)

// Icon boxes (32x32)
Container(
  width: 32,
  height: 32,
  decoration: BoxDecoration(
    color: theme.colorScheme.primary.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
)

// Tile padding
EdgeInsets.symmetric(horizontal: 16, vertical: 14)
```

### Widget Organization
- Private builder methods: `_buildMethodName`
- Stateless helper widgets: private classes (e.g., `_ReminderTimeTile`)
- Use `AppTheme` constants for radii, colors, durations
- Use `FadeInSlide` with index for stagger animations

### Section Cards
```dart
FadeInSlide(
  index: 0,
  child: _buildSectionCard(
    context,
    title: 'Section Title',
    icon: Icons.icon_outlined,
    children: [...],
  ),
)
```

### Anti-patterns
```dart
// DON'T
SwitchListTile(title: Text('Setting'), value: value, onChanged: onChanged)

// DO
_buildSwitchTile(context, title: 'Setting', subtitle: 'Description',
  icon: Icons.settings_outlined, value: value, onChanged: onChanged)
```

## Providers

Use Provider pattern with `ChangeNotifier`:
```dart
context.read<Provider>()    # One-time read
context.watch<Provider>()   # Reactive updates
Consumer<Provider>()        # Rebuild on changes
```

## Theme
- Use `AppTheme` for consistent styling values
- Access via `Theme.of(context)`
- Use semantic colors from `theme.colorScheme`

## Testing

### Test Structure
- Test files: `test/services/<filename>_test.dart`
- Use `flutter_test` and `mocktail` for mocking
- Group tests with `group()` and name with past tense: `'FoodEntryFactory'`

### Example Test Pattern
```dart
void main() {
  group('FoodEntryFactory', () {
    test('builds a food entry from a food item and portion size', () {
      const item = FoodItem(...);
      final entry = FoodEntryFactory.fromFoodItem(...);
      expect(entry.calories, 78);
    });
  });
}
```

## Database (Drift)

Generated files are excluded from analysis:
```yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
```

After modifying Drift tables, regenerate:
```bash
dart run build_runner build --delete-conflicting-outputs
```
