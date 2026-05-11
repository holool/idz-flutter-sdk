/// Exception types for the IDz Flutter SDK.
///
/// This module provides error handling types used throughout the SDK:
/// - [KycFailure]: Sealed class representing expected KYC verification failures
/// - [Either]: Result type for error handling (Left = failure, Right = success)
/// - [IdzException]: Exception for unrecoverable SDK errors
/// - [KycResult]: Type alias for async KYC operations

export 'kyc_failure.dart';
export 'either.dart';
export 'idz_exception.dart';
