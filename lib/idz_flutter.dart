/// IDz Flutter SDK — KYC verification client for the IDz API.
library idz_flutter;

// Entry point + config
export 'src/idz_config.dart';
export 'src/idz_flutter.dart';

// Client
export 'src/client/idz_api_client.dart';

// Models
export 'src/models/api_error.dart';
export 'src/models/artifacts_catalog.dart';
export 'src/models/document_type.dart';
export 'src/models/field_result.dart';
export 'src/models/verification.dart';

// Errors
export 'src/exceptions/either.dart';
export 'src/exceptions/kyc_failure.dart';

// Webhook helper
export 'src/webhooks/idz_webhooks.dart';

// Widgets — UI helpers, optional
export 'src/widgets/nfc_reading_screen.dart';
export 'src/widgets/document_capture_screen.dart';
export 'src/widgets/kyc_progress_overlay.dart';
export 'src/widgets/kyc_result_card.dart';
export 'src/widgets/liveness_recording_screen.dart';
export 'src/widgets/selfie_capture_screen.dart';
export 'src/widgets/verification_result_page.dart';
export 'src/widgets/result/artifact_thumb.dart';
export 'src/widgets/result/categories_table_card.dart';
export 'src/widgets/result/mrz_section.dart';
export 'src/widgets/result/postprocess_notes.dart';
