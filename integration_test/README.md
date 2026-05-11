# IDz Flutter SDK - Integration Tests

End-to-end tests that verify the full app flow using a mock backend server.

## What is tested

| Group | Verifies |
|-------|----------|
| **Tab Navigation** | All three tabs render and navigation works |
| **Complete KYC Flow** | Idle UI, step indicators, icons, mock server health check |
| **KYC with Video Flow** | Video-specific UI elements, 5-step indicators, health check |
| **OCR Only Flow** | OCR-specific UI, 3-step indicators, health check |
| **Mock Server Integration** | OS-assigned port, request logging, response overrides |

> **Note:** Integration tests cannot access the device camera. They verify UI
> structure, navigation, and mock API connectivity — not actual image capture.

## Running

```bash
# From sdks/flutter:
flutter test integration_test/

# Run a specific test file:
flutter test integration_test/app_test.dart

# With verbose output:
flutter test integration_test/ --reporter expanded
```

## Architecture

```
integration_test/
├── app_test.dart      # All test groups (navigation, KYC flows, mock server)
├── test_utils.dart    # Shared helpers: mock server, test app builder, screenshots
└── README.md          # This file
```

- **`test_utils.dart`** builds a minimal test app that mirrors the example app's
  tab structure using SDK widgets. It also re-exports the mock server from
  `test/helpers/mock_api_server.dart`.
- **`app_test.dart`** contains all integration test groups. Each test starts a
  fresh mock server in `setUp` and tears it down in `tearDown`.

## Adding new tests

1. Import `test_utils.dart` for all helpers.
2. Use `startMockServer()` / `mockServer.stop()` for server lifecycle.
3. Use `buildTestApp(mockBaseUrl: mockServer.baseUrl)` to create the test app.
4. Use `pumpAndSettleApp(tester)` instead of raw `tester.pumpAndSettle()`.
5. Use `mockServer.setResponse(path, status, body)` to override endpoint responses.
6. Use `takeScreenshot(binding, name)` for debugging failures.
