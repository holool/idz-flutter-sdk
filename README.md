# idz_flutter

Flutter SDK for the [IDz](https://idz.holool.dev) KYC verification API.

Verifies Algerian national IDs and driving licences via the
`/v1/verifications/*` HTTP surface, with optional face match and passive
liveness. Strongly-typed responses, idempotent retries, a webhook
signature helper, and a small set of capture + result UI widgets.

> Status: **`0.1.0` — pre-release.** API surface and types may still
> change before `1.0`. Pin to a specific git ref if you need stability.

## Features

- Async-by-default POST flow — every verifyXxx call returns a 202 +
  in-progress Verification, then polls until terminal (with a
  configurable timeout). One call, one Future, one typed result.
- Three modes: document-only, document + selfie face match,
  document + selfie + liveness video.
- ICAO 9303 TD1 MRZ on the wire with per-field check digits and
  VIZ-backfill provenance (`fields_from_viz`).
- Sealed `KycFailure` variants — pattern-match every failure mode.
- HMAC-SHA256 webhook signature verification with constant-time
  compare + timestamp tolerance.
- Ready-made widgets: `DocumentCaptureScreen`, `SelfieCaptureScreen`,
  `LivenessRecordingScreen`, `NfcReadingScreen`, `KycResultCard`, and
  `VerificationResultPage` (tabbed Fields table + Artifacts gallery).

## Install

```yaml
dependencies:
  idz_flutter:
    git:
      url: https://github.com/holool/idz-flutter-sdk.git
      ref: main   # or a tag once we cut one
```

## First request

```dart
import 'dart:io';
import 'package:idz_flutter/idz_flutter.dart';

final idz = IdzFlutter(
  config: IdzConfig(apiKey: 'idz_test_…'),
);

final result = await idz.client.verifyDocument(
  idFront: File('/path/to/front.jpg'),
  idBack:  File('/path/to/back.jpg'),
  documentType: DocumentType.algerianDrivingLicense,
  idempotencyKey: 'order-12345',
);

result.fold(
  (failure) => print('failed: $failure'),
  (verification) {
    print('id: ${verification.id}');
    print('status: ${verification.status}');
    final lastName = verification.document?.fields?['last_name_fr']?.normalized;
    print('last name (Latin): $lastName');
  },
);

idz.dispose();
```

The API key goes in `IdzConfig.apiKey` and is sent as
`Authorization: Bearer <key>` on every request. **Never commit a live key
to source or ship it inside a public client build** — fetch a short-lived
scoped key from your own backend at runtime.

## Picking a mode

Three POST methods on `IdzApiClient`, matching the three API endpoints:

```dart
sdk.client.verifyDocument(...);       // OCR only, no biometric
sdk.client.verifyIdentity(...);       // + selfie face match
sdk.client.verifyIdentityLive(...);   // + selfie + liveness video
```

All three accept the same `documentType` and `idempotencyKey` arguments.
Allowed document types:

| `DocumentType`                       | Wire value                  |
| ------------------------------------ | --------------------------- |
| `DocumentType.algerianNationalId`    | `algerian_national_id`      |
| `DocumentType.algerianDrivingLicense`| `algerian_driving_license`  |

## Reading a response

`Verification` is the canonical response shape across every endpoint:

```dart
final fields = verification.document?.fields ?? {};

// Each field is a {raw, normalized, valid, side} record.
final fr = fields['license_number'];
print(fr?.asString);     // String | null
print(fr?.valid);        // bool | null

// `categories` is a list-typed field on driving licences.
final cats = fields['categories']?.asStringList; // ['A', 'B', 'C1', ...]
```

The three checks each verification can run:

```dart
verification.checks.document?.passed;
verification.checks.faceMatch?.score;
verification.checks.liveness?.failureReason;
```

A `null` check means the chosen mode didn't evaluate it. `passed: false`
means it ran and failed — surface `failureReason`.

## Error handling

`KycResult<T>` = `Future<Either<KycFailure, T>>`. `KycFailure` is a sealed
class — pattern-match on the variant:

```dart
switch (failure) {
  KycFailureNetwork() => showOffline(),
  KycFailureUnauthorized() => promptForApiKey(),
  KycFailureInvalidInput(:final errorCode)
      when errorCode == 'unsupported_document_type' => showUnsupported(),
  KycFailureIdempotencyConflict() => showRetryLater(),
  KycFailureVerificationRejected(:final verification)
      => showRejection(verification.checks.document?.failureReason),
  KycFailureServerError(:final statusCode) => showServerError(statusCode),
  _ => showGenericError(),
}
```

A 200 OK with `status: "rejected"` is surfaced as
`KycFailureVerificationRejected` with the full `Verification` attached so
you can render the per-check `failureReason`.

## Idempotency

Pass an `idempotencyKey` (any unique string per logical operation; UUIDs
are fine) to make a POST safe to retry. The server replays the cached
response of the first call instead of re-running the pipeline. A second
call while the first is still in flight returns
`KycFailureIdempotencyConflict`.

## Webhook signatures

The `/v1/webhook_endpoints` API delivers signed events to your URL. Verify
the signature before trusting the body:

```dart
final ok = IdzWebhooks.verifySignature(
  secret: yourEndpointSigningSecret,
  body: rawRequestBodyBytes,            // do NOT parse first
  signatureHeader: req.headers['x-idz-signature']!,
);
if (!ok) return Response(401);
```

The check is HMAC-SHA256 with constant-time compare and a 5-minute
timestamp tolerance.

## Reading verifications back

```dart
final list = await sdk.client.listVerifications(status: 'completed');
final detail = await sdk.client.getVerification('kyc_…');
final audit = await sdk.client.getVerificationAudit('kyc_…');
final artifact = await sdk.client.getArtifactBytes('kyc_…', 'art_…');
```

`document.fields` is omitted from `listVerifications` rows to keep
payloads small — fetch `getVerification` for the full map.

## UI helpers

The package also exports ready-made widgets for the common screens:

- `NfcReadingScreen` — read the ID's NFC chip via BAC and pull MRZ + face.
- `LivenessRecordingScreen` — guided video capture for the liveness step.
- `DocumentCaptureScreen`, `SelfieCaptureScreen` — file capture UIs.
- `KycResultCard` — compact result preview with all checks and fields.
- `VerificationResultPage` — full-screen result viewer with a Fields
  tab (table + MRZ section + soft cross-check badges) and an
  Artifacts tab (lazy-loaded crop gallery backed by
  `/v1/verifications/{id}/artifacts`).

## Example app

Run the example under `example/`:

```sh
cd example
flutter run
```

Set your API key, base URL, and default document type on the Settings
tab, then run a verification on the Verify tab.

## Contributing & support

- Bugs and feature requests: [issues](https://github.com/holool/idz-flutter-sdk/issues)
- API docs: <https://idz.holool.dev>
- Server-side source + SDK release notes: see [`CHANGELOG.md`](./CHANGELOG.md)

## License

[MIT](./LICENSE) © 2026 Holool.
