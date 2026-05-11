# Changelog

## 0.1.0

Breaking change. The SDK now targets the `/v1/verifications/*` API surface
introduced in IDz v1; the prior `/v1/kyc/id/*` paths were removed
server-side.

### Added

- `IdzApiClient.verifyDocument`, `verifyIdentity`, `verifyIdentityLive` —
  three POST methods that match the three API endpoints. Each accepts an
  optional `documentType` (default `algerianNationalId`) and
  `idempotencyKey`.
- `IdzApiClient.listVerifications`, `getVerification`,
  `getVerificationAudit`, `getArtifactBytes` — GET surface.
- `DocumentType` enum: `algerianNationalId`, `algerianDrivingLicense`.
- `Verification` / `VerificationDocument` / `FieldResult` /
  `CheckResult` / `VerificationChecks` / `VerificationArtifact` /
  `VerificationList` / `VerificationAuditEntry` — strongly-typed
  models matching the API's wire shape, including the per-field
  `{raw, normalized, valid, side}` record.
- `IdzWebhooks.verifySignature(...)` — HMAC-SHA256 helper with constant-
  time compare and timestamp tolerance for verifying webhook deliveries.
- `IdzConfig.apiKey` — required. Sent as `Authorization: Bearer <key>` on
  every request. `IdzConfig.baseUrl` now defaults to
  `https://api.idz.holool.dev`.
- `KycFailure` variants: `unauthorized`, `forbidden`, `invalidInput`
  (with `errorCode`), `idempotencyConflict`, `notFound`, and
  `verificationRejected` (carrying the full `Verification`). One
  variant per HTTP status the API emits.

### Removed

- `IdzApiClient.completeKyc`, `completeKycWithVideo`, `ocrFront`,
  `ocrBack`, `ocrMrz`, `classify`, `extractRois`, `faceMatchCard`,
  `livenessPassive`, `frontOnly`, `backOnly`, `getDemoSamples`,
  `runDemoSample` — replaced by the verify methods above.
- `OcrData`, `CompleteKycResponse`, `ClassifyResponse`,
  `FaceMatchResponse`, `LivenessResponse`, `RoisResponse`,
  `HealthResponse`, `DemoSample`, `DashboardStats`, `ApiResponse` —
  obsolete with the new wire shape.
- The example app's `complete_kyc_screen`, `kyc_with_video_screen`,
  `ocr_only_screen`, `nfc_scan_screen` — replaced by a single
  `verify_screen` that drives the new API.

### Changed

- The package no longer uses `freezed` / `json_serializable` for
  models — replaced with hand-written plain Dart classes (Dart 3
  sealed classes for `KycFailure`).
- The example app gates the Verify tab on a configured API key; first
  launch opens Settings.

## 0.0.1

Internal pre-release. Targeted the now-removed `/v1/kyc/id/*` API.
