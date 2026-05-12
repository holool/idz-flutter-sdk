# Changelog

## 0.1.3

Surfaces the server's MRZ → VIZ fallback so the UI stops looking
broken when the MRZ is partially OCR-damaged but the values are
correct (recovered from the front-side independent OCR).

### Added

- `MrzNormalized.fieldsFromViz` (`List<String>?`) — snake-case field
  names the server replaced via `fill_mrz_from_viz` because the
  MRZ-side value was damaged or the ICAO check digit failed. Drawn
  from `document_number` / `date_of_birth` / `expiry_date` / `sex` /
  `surname` / `given_names`.
- `MrzNormalized.isFromViz(String key)` — null/empty-safe membership
  check.

### Changed

- `MrzSection` per-row trailing icon now distinguishes three states:
  - **Green ✓** — ICAO check passed.
  - **🔄 info** (new) — value was filled from the front-side VIZ
    because the MRZ-side was unreliable. Tooltip explains: the
    displayed value is trustworthy; the MRZ just couldn't prove it.
  - **Red ✗** — ICAO check failed AND no VIZ fallback was available;
    treat the value with suspicion.
- Top-right badge has a third state: **Recovered** (yellow) when the
  MRZ-level `valid` is false but at least one field was rescued from
  VIZ. Previously this case showed as "Invalid" even though the
  displayed data was correct — confusing.

## 0.1.2

### Added

- `FieldResult.issues` — surfaces per-field pipeline issues the server
  was already emitting but the SDK ignored. Each entry is a
  `FieldIssue` carrying `code` / `message` / optional
  `severity` / optional `details` map.
- `FieldResult.lowQualityIssue` — convenience getter returning the first
  `low_quality_field` issue, or null. Use it to gate UI badges.
- `FieldIssue.confidence` — typed accessor for the 0..1 confidence
  embedded in `details["confidence"]` on `low_quality_field` issues.
- `FieldsTab` now renders a yellow ⚠ **Low quality** chip next to any
  field that carries a `low_quality_field` issue. The tooltip uses the
  API's pre-formatted message (which already includes the confidence
  percentage), falling back to a generic blurb only when the message
  is empty.

### Internal

- No wire-shape changes. Pre-0.1.2 servers that don't emit `issues`
  remain compatible — the list parses as empty and no chip renders.

## 0.1.1

UI polish for the verification-result widgets. No API or wire-shape
changes — the underlying `Verification` / `FieldResult` /
`MrzNormalized` models are unchanged.

### Added

- `CategoriesTableCard` — collapsible card rendering the driving-licence
  categories table (`field_results["categories_table"].normalized`) as
  a real `DataTable` with `CLASS | ISSUED | EXPIRES | RESTRICTIONS`
  columns and a coloured chip per category. Header shows a count badge
  (e.g. "4 categories"). Hidden when the field is absent or empty
  (national IDs, or DLs where the back-side table parse came up empty).
  Re-exported from `package:idz_flutter/idz_flutter.dart`.

### Changed

- `MrzSection` (also now re-exported):
  - Top-right badge now reads **Valid** / **Invalid** (was
    "MRZ verified" / "MRZ invalid"). Same semantics, tighter copy.
  - Per-row ICAO 9303 check icons inline on **Document #**,
    **Date of birth**, **Expiry** rows — green ✓ / red ✗ driven by
    `mrz.checks.documentNumber` / `dateOfBirth` / `expiryDate`. Tooltips
    explain the icon meaning.
  - The standalone **Composite** check chip is dropped from the UI. It
    fails on a sizeable fraction of Algerian cards because OCR drops
    line-2 filler characters — useful as a server-side diagnostic, noisy
    and confusing as a top-level user-facing signal. Still available
    on `mrz.checks.composite` for callers that want to surface it.
  - Dates render as `dd MMM yyyy` (e.g. `02 Aug 1982`) via
    `intl.DateFormat`, falling back to the raw `YYYY/MM/DD` string if
    parsing fails.

### Internal

- `FieldsTab` now lifts `categories_table` out of the main fields
  table in the same way it lifts MRZ — both render as their own card.
  When the categories list is empty the field stays in the main table
  so the user still sees the field name rather than nothing.

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
