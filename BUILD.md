# Building IDz Flutter SDK

## Prerequisites
- Flutter SDK 3.16.0 or higher
- Android SDK (for Android builds)
- Xcode (for iOS builds, macOS only)

## Quick Verification
```bash
cd sdks/flutter
./tool/verify_build.sh
```

## Manual Steps

### Analyze
```bash
flutter analyze
cd example && flutter analyze
```

### Test
```bash
flutter test
```

### Build Example App
```bash
cd example
flutter build apk --debug        # Android
flutter build ios --simulator    # iOS (macOS only)
```

## Troubleshooting

### CocoaPods issues (iOS)
```bash
cd example/ios
pod install --repo-update
```

### Gradle issues (Android)
```bash
cd example/android
./gradlew clean
```
