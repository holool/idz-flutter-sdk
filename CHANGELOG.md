# Changelog

## 0.2.0

The IDz API is fully async on prod: submissions return `202 Accepted`
and the row finishes on a worker as `completed | rejected | failed`,
and `completed` can now also mean "approved but pending human review".
The SDK catches up — verify methods no longer block on a poll loop,
and result UIs render a five-state verdict that surfaces the new
`review_state` cleanly.

### Breaking

- `Verification.isPassed` now requires `reviewState == null`. A
  `status == 'completed'` row with `review_state: pending` is no
  longer "verified" — it's `isUnderReview`. Render amber, not green.
- `ArtifactItem.url` → `ArtifactItem.href`. JSON parsing still accepts
  the legacy `url` key as a fallback for the transition window.
- `FaceMatchArtifacts.selfie` → `FaceMatchArtifacts.selfieCrop`;
  `FaceMatchArtifacts.idPhoto` → `FaceMatchArtifacts.documentFaceCrop`.
  JSON parsing accepts the legacy `selfie` / `id_photo` keys as
  fallbacks.
- Client-side polling is removed from `verifyDocument` /
  `verifyIdentity` / `verifyIdentityLive`. They now return the
  initial `202 Accepted` response (typically `status: in_progress`)
  immediately. Apps drive terminal-state reads through
  `fetchVerification` (or a webhook).

### Added

- `Verification.reviewState` — new `ReviewState?` field parsed from
  `review_state` (currently `null` or `pending`).
- `Verification.isUnderReview`, `isInProgress`, `isFailed`,
  `isTerminal` helpers, plus the updated `isPassed` semantics.
- `FieldResult.criticality` (`FieldCriticality.critical` /
  `optional` / `unknown`) parsed from `criticality` on the wire
  (accepts string or bool). Use `field.isCritical` instead of a
  client-side allowlist.
- `IdzApiClient.fetchVerification(id)` — alias of `getVerification`,
  named to match how apps now drive refreshes (lifecycle resume,
  pull-to-refresh, tab-switch).
- Idempotency-Key is now sent on every verify POST. When the caller
  doesn't supply one the SDK generates a v4 UUID via
  `Random.secure()` (`IdempotencyKey.generate()`). The SDK does not
  cache the generated key — host apps that want submit-retry replay
  must supply (and persist) their own.
- `VerdictTone` enum + `VerdictChip` widget — five-quadrant
  rendering keyed off `(status, reviewState)`: `inProgress`,
  `verified`, `underReview`, `rejected`, `failed`. Drop into list
  rows for consistent verdict styling.
- `KycResultCard` rewritten to render the five states distinctly,
  pull error copy from `verification.error?.userMessage` (or
  `checks.document.error.userMessage` as a fallback), and map
  `error.userAction` onto a primary action button via the optional
  `onAction` callback. "Try again" appears only when
  `error.retryable == true`. `developerMessage` is never rendered.
- `UserAction.retry` — new wire value for transient server errors
  (`SERVER_ABANDONED`, generic `INTERNAL_ERROR`) where the same
  request resubmitted as-is is likely to succeed. Distinct from
  `waitAndRetry` (suggest a backoff) and `retakeDocument` /
  `retakeSelfie` / `retakeLiveness` (need new user input).
- Typed accessors on `Verification` for the structured `metadata`
  advisory blobs the server attaches on rejected / `needs_review`
  rows. Each accessor returns an empty list / `null` when the blob
  isn't present, so call sites don't need to null-check the raw map:
  - `missingFrontFields` / `missingBackFields` (`List<String>`) —
    YOLO classes the detector couldn't find, paired with a
    `MISSING_REQUIRED_FIELDS` rejection.
  - `qualityFailures` / `qualityScoresAll` (`List<QualityScore>`) —
    per-region blur / glare scores. `qualityFailures` only contains
    the regions that tripped the gate; `qualityScoresAll` covers
    every scored region (passing AND failing) so triage UIs can
    render the distribution next to an `IMAGE_QUALITY_REJECTED`
    rejection.
  - `mrzVizDisagreements` (`List<MrzVizDisagreement>`) — field-level
    disagreements between the MRZ-side and visible-zone OCR. Most
    flag the row for `needs_review` rather than reject.
  - `consistencyIssues` (`List<FieldFinding>`) — cross-field date /
    validity-window checks the pipeline flagged.
  - `gazetteMisses` (`List<FieldFinding>`) — names or places that
    weren't in the reference gazette.
  - `routing` (`RoutingDecision?`) — verdict + index / core / soft
    failure buckets + review reasons. Present on every terminal
    verification; `null` while `isInProgress`.

### Wire-shape notes

- `ArtifactItem.fieldName` is now populated for per-field crops (the
  YOLO class — `first_name_fr`, `blood_type`, …) thanks to
  server-side field-name plumbing. UIs can attach the right thumbnail
  to the right row without filename-substring matching. Legacy rows
  persisted before the change still parse as `fieldName == null`;
  substring matching keeps working as a fallback for those.
- Wire-shape additive otherwise — the new `metadata` keys, the
  `retry` action, and the new `error.code` values from the recent
  rejection-catalog work all parse cleanly on older servers that
  don't emit them yet (every accessor returns an empty list /
  `null` when the field is absent).

### Deprecated

- `IdzApiClient.defaultPollTimeout` and the `pollTimeout` parameter
  on every verify method. Both are accepted for source-compat but
  ignored — the SDK no longer polls.

## 0.1.4

Adopts the IDz API's new structured error object. The legacy
`failure_reason` string is still emitted server-side as a copy of
`error.code` for backward compat; new SDK code should switch on
`error.code` and render `error.userMessage` (or its localized
counterpart via code lookup).

### Added

- `ApiError` model (`code` / `developerMessage` / `userMessage` /
  `userAction` / `retryable`). The `code` is the stable machine-
  readable identifier — switch on it rather than parsing message
  strings.
- `ApiError.hasUserContent` — true iff `userMessage` is non-empty.
  Dev-only codes (`AUTH_REQUIRED`, `RESOURCE_NOT_FOUND`, rate-limits)
  carry empty `userMessage` deliberately; UI code MUST gate
  rendering on this.
- `UserAction` enum — `retakeDocument` / `retakeSelfie` /
  `retakeLiveness` / `improveImageQuality` / `waitAndRetry` /
  `contactSupport` / `none`. Snake-case wire values exposed via
  `UserAction.wireValue` for round-trip.
- `Verification.error` — top-level structured error for whole-
  verification failures.
- `CheckResult.error` — per-check structured error (on `document` /
  `faceMatch` / `liveness`).

### Changed

- `KycResultCard` now prefers `error.userMessage` over
  `failureReason` when rendering failure banners. The banner also
  shows a small chip describing the suggested `userAction`
  (e.g. "Retake document"). Banners are skipped entirely for
  dev-only codes (empty user_message).

### Compatibility

- Wire-shape additive — pre-`0.1.4` servers that don't emit
  `error` parse as `null`, and the SDK falls back to the legacy
  `failureReason` path. No client code changes required for
  consumers staying on the old shape.

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
