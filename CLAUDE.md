# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SolidTask is a cross-platform Flutter todo application implementing cutting-edge distributed data technologies:
- **Offline-first architecture** with CRDT (Conflict-Free Replicated Data Types) for conflict resolution
- **Solid Pod integration** for decentralized data storage using RDF/Linked Data
- **Cross-platform** support (iOS, Android, macOS, Linux, Windows, Web)
- **Vector clock-based synchronization** for multi-device collaborative editing

## Development Commands

### Essential Commands
```bash
# Generate localization files (only needed when i18n was changed)
flutter gen-l10n

# Run the app on macOS
flutter run -d macos

# Run on other platforms
flutter run -d chrome  # Web
flutter run -d ios     # iOS Simulator
flutter run -d android # Android Emulator

# Generate code (RDF mappers, Hive adapters, mocks)
flutter packages pub run build_runner build

# Clean and regenerate all generated code
flutter packages pub run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Run integration tests
flutter test integration_test/

# Run specific test file
flutter test test/path/to/test_file.dart

# Run tests with coverage
flutter test --coverage

# Analyze code
flutter analyze
```

### Solid Pod Authentication Requirements

**CRITICAL**: This app requires Solid-OIDC compliant providers with specific features:
- ✅ **Compatible**: Inrupt ESS, SolidCommunity.net, Community Solid Server
- ❌ **Incompatible**: iGrant.io (lacks client identifier documents)

The app uses public client identifier documents and requires providers that support:
- Solid-OIDC specification (not just basic OIDC)
- Client Identifier Documents (WebID-based client identification)
- Public clients with `token_endpoint_auth_method: "none"`
- WebID scope in OIDC flows

## Architecture Overview

### Dependency Injection Pattern

The app uses a sophisticated service locator pattern built on GetIt with a custom builder system:

```dart
// Service registration happens in extensions under lib/bootstrap/extensions/
// Order matters due to dependencies:
1. Core services (logging, HTTP)
2. Client ID service
3. Storage services (Hive)  
4. RDF mapping services
5. Authentication services (Solid-OIDC)
6. Repository services (data access)
7. Sync services (Solid Pod sync)
8. Syncable repository (combines local + sync)
```

**Key files:**
- `lib/bootstrap/service_locator.dart` - Main initialization
- `lib/bootstrap/service_locator_builder.dart` - Builder pattern
- `lib/bootstrap/extensions/` - Service registration extensions

### Data Layer Architecture

**CRDT Implementation:**
- `lib/models/item.dart` - Main data model with vector clocks
- Vector clock entries track changes per client/device
- Automatic conflict resolution via CRDT merge operations
- RDF mapping annotations for Solid Pod serialization

**Storage Strategy:**
- **Local**: Hive database for offline-first operations
- **Remote**: RDF/Turtle files stored in Solid Pods
- **Sync**: Bidirectional synchronization with conflict resolution

### Solid Integration

**Key components:**
- `lib/ext/solid/` - Solid protocol implementations
- `lib/ext/solid/auth/` - OIDC authentication
- `lib/ext/solid/sync/` - Pod synchronization
- `lib/ext/solid/pod/` - Pod storage and profile management

**RDF Mapping:**
- Uses `rdf_mapper` package for automatic RDF serialization
- Custom vocabularies in `lib/solid_integration/vocab.dart`
- Generated code in `*.rdf_mapper.g.dart` files

### Testing Architecture

**Comprehensive test setup:**
- **Unit tests**: `test/` directory with extensive mocking
- **Integration tests**: `integration_test/` for end-to-end scenarios
- **Widget tests**: Full app testing with mock service locator
- **Mock setup**: Custom mock implementations in `test/mocks/`

**Test execution patterns:**
```dart
// Tests use BehaviorSubject for realistic stream behavior
// Service locator is reset after each test
// Temporary directories are used for test isolation
// Locale testing includes both English and German
```

### Code Generation

The project relies heavily on code generation:
- **RDF Mappers**: `*.rdf_mapper.g.dart` for Solid Pod serialization
- **Hive Adapters**: `*.g.dart` for local storage
- **Test Mocks**: `*.mocks.dart` for testing
- **Localizations**: Auto-generated from ARB files

### Multi-platform Considerations

**Platform-specific code:**
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/` directories
- Platform channels for secure storage and authentication
- NSAllowsArbitraryLoads required for iOS/macOS (user-provided Pod URLs)

### Localization

- English (`en`) and German (`de`) supported
- ARB files in `lib/l10n/`
- Auto-generated with `flutter gen-l10n`

## Development Workflow

1. **Make changes** to Dart code
2. **Run code generation** if modifying models or RDF mappings:
   ```bash
   flutter packages pub run build_runner build
   ```
3. **Test locally** with appropriate platform
4. **Run tests** to ensure functionality
5. **Analyze code** for linting issues

## Important Notes

- Generated files are committed to version control for reproducible builds and efficiency
- Always run `flutter analyze` before committing
- RDF mapping changes require regeneration and may affect Solid Pod compatibility
- Service locator initialization order is critical - follow the established pattern
- Authentication testing requires compatible Solid Pod providers
- Never refer in code comments to previous state of the code, always refer to the status quo. The reader does not care about how it was, but about how it is.