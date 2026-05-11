# IDz Flutter SDK Example

Demo app for the `idz_flutter` package and the `/v1/verifications/*` API.

## What It Shows

- Configuring `IdzConfig` with an API key, base URL, and default document type.
- Running document-only verification with `verifyDocument`.
- Running identity verification with `verifyIdentity`.
- Running identity + liveness verification with `verifyIdentityLive`.
- Rendering successful `Verification` results with `KycResultCard`.
- Displaying typed `KycFailure` values for failed requests.

## Run

From this directory:

```sh
flutter pub get
flutter run
```

On first launch, open the Settings tab and enter:

- API key: an IDz test key such as `idz_test_...`.
- Base URL: defaults to `https://api.idz.holool.dev`; override only for local or staging APIs.
- Document type: Algerian national ID or Algerian driving licence.

The Verify tab is disabled until an API key is configured.

## Local API

If you are running the FastAPI backend locally from `services/api`, start it with:

```sh
uvicorn kyc_api:app --reload
```

Use these base URLs in the example app:

- iOS simulator: `http://localhost:8000`
- Android emulator: `http://10.0.2.2:8000`
- Physical device: `http://<your-machine-lan-ip>:8000`

## Modes

- Document: requires ID front and ID back images.
- Identity: requires ID front, ID back, and selfie images.
- Identity + live: requires ID front, ID back, selfie image, and liveness video.

Files are selected from the device gallery to keep the example simple and deterministic. The SDK also exports capture widgets (`DocumentCaptureScreen`, `SelfieCaptureScreen`, and `LivenessRecordingScreen`) for apps that want an in-app capture flow.

## Development

From the SDK root (`sdks/flutter`):

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

## Security Note

The example stores the API key in `SharedPreferences` only to make local testing convenient. Production mobile apps should fetch a short-lived scoped key from their own backend at runtime and must not embed live IDz API keys in public client builds.
