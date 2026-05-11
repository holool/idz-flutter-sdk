import 'kyc_failure.dart';

/// A sealed class representing a value of one of two possible types (a disjoint union).
///
/// An instance of [Either] is either an instance of [Left] or an instance of [Right].
///
/// This is commonly used for error handling where [Left] represents a failure
/// and [Right] represents a success.
sealed class Either<L, R> {
  const Either();

  /// Applies one of two functions based on whether this is a [Left] or [Right].
  ///
  /// If this is a [Left], applies [onLeft] to the left value.
  /// If this is a [Right], applies [onRight] to the right value.
  B fold<B>(B Function(L left) onLeft, B Function(R right) onRight);

  /// Returns true if this is a [Left].
  bool get isLeft;

  /// Returns true if this is a [Right].
  bool get isRight;
}

/// A [Left] represents the failure case of an [Either].
final class Left<L, R> extends Either<L, R> {
  /// The failure value.
  final L value;

  const Left(this.value);

  @override
  B fold<B>(B Function(L left) onLeft, B Function(R right) onRight) =>
      onLeft(value);

  @override
  bool get isLeft => true;

  @override
  bool get isRight => false;

  @override
  String toString() => 'Left($value)';
}

/// A [Right] represents the success case of an [Either].
final class Right<L, R> extends Either<L, R> {
  /// The success value.
  final R value;

  const Right(this.value);

  @override
  B fold<B>(B Function(L left) onLeft, B Function(R right) onRight) =>
      onRight(value);

  @override
  bool get isLeft => false;

  @override
  bool get isRight => true;

  @override
  String toString() => 'Right($value)';
}

/// Type alias for a KYC operation result.
///
/// [KycResult<T>] represents an asynchronous operation that either fails with
/// a [KycFailure] (left) or succeeds with a value of type [T] (right).
typedef KycResult<T> = Future<Either<KycFailure, T>>;
