/// Exception thrown for unrecoverable SDK errors.
///
/// [IdzException] is used for errors that occur during SDK initialization
/// or other critical operations that cannot be recovered from. Unlike
/// [KycFailure] which represents expected business failures, [IdzException]
/// represents unexpected or configuration errors.
class IdzException implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// Creates a new [IdzException] with the given [message].
  IdzException(this.message);

  @override
  String toString() => 'IdzException: $message';
}
