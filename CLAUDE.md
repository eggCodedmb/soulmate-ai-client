# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SoulMate AI (灵魂伴侣AI) is a Flutter mobile application for AI companion chat. Users can create personalized AI companions with different personalities, genders, and relationship types, then chat with them in real-time.

## Common Commands

```bash
# Run the app
flutter run

# Run on specific device
flutter run -d <device_id>

# Build APK
flutter build apk

# Build for iOS
flutter build ios

# Run tests
flutter test

# Run single test file
flutter test test/path/to/test.dart

# Analyze code
flutter analyze

# Format code
dart format .

# Generate code (for freezed/json_serializable models)
dart run build_runner build --delete-conflicting-outputs

# Watch for changes and regenerate
dart run build_runner watch --delete-conflicting-outputs

# Get dependencies
flutter pub get
```

## Architecture

### State Management: Riverpod

The app uses `flutter_riverpod` for dependency injection and state management. Providers are defined in:
- `lib/core/di/providers.dart` - Global providers (secure storage, database, WebSocket, theme)
- `lib/core/network/api_client.dart` - API client and Dio providers
- `lib/core/network/api_service.dart` - API service provider

### Routing: GoRouter

Navigation uses `go_router` with `StatefulShellRoute` for bottom tab navigation. Route configuration is in `lib/core/routing/app_router.dart`.

**Route structure:**
- `/splash` - Splash screen
- `/onboarding` - First-time user onboarding
- `/auth` - Login/authentication
- `/home` - Home tab (Tab 0)
- `/conversations` - Chat list tab (Tab 1)
- `/conversations/chat/:id` - Chat detail
- `/partners` - Companion management tab (Tab 2)
- `/profile` - Profile tab (Tab 3)
- `/profile/settings` - Settings page

### Network Layer

- `lib/core/network/api_client.dart` - Dio HTTP client with automatic failover between primary (`192.168.2.240:8080`) and fallback (`10.2.3.6:8080`) servers
- `lib/core/network/api_service.dart` - Typed API methods and DTOs
- `lib/core/network/websocket_service.dart` - WebSocket for real-time messaging
- `lib/core/network/interceptors/` - Auth token injection and logging interceptors

**API response format:** All endpoints return `{ code: int, message: String, data: any }`. Code `0` indicates success.

### Storage

- `lib/core/storage/local_storage.dart` - SharedPreferences wrapper for user preferences and app state
- `lib/core/storage/secure_storage.dart` - FlutterSecureStorage for sensitive data (auth tokens)
- `lib/core/storage/database/app_database.dart` - Local database

### Data Models

Models are in `lib/shared/models/` with manual `fromJson`/`toJson` serialization:
- `companion.dart` - AI companion entity
- `conversation.dart` - Chat conversation
- `message.dart` - Chat message
- `user.dart` - User and profile data
- `memory.dart` - Companion memory
- `subscription.dart` - Subscription plans

### Feature Modules

Each feature is in `lib/features/<name>/`:
- `splash` - App launch screen
- `onboarding` - First-time user guide
- `auth` - Email verification login and guest login
- `home` - Main home page
- `chat` - Chat interface with AI companion
- `partner` - Companion CRUD management
- `profile` - User profile
- `settings` - App settings (theme, language, model config)

## Code Style

- Uses `very_good_analysis` for linting with relaxed rules (see `analysis_options.yaml`)
- Chinese comments are acceptable throughout the codebase
- Manual JSON serialization (no code generation for models currently)
