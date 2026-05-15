sealed class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => message;
}

final class ValidationAppException extends AppException {
  const ValidationAppException(super.message, {super.code, super.cause});
}

final class NotFoundAppException extends AppException {
  const NotFoundAppException(super.message, {super.code, super.cause});
}

final class PermissionAppException extends AppException {
  const PermissionAppException(super.message, {super.code, super.cause});
}

final class NetworkAppException extends AppException {
  const NetworkAppException(super.message, {super.code, super.cause});
}

final class UnexpectedAppException extends AppException {
  const UnexpectedAppException(super.message, {super.code, super.cause});
}

typedef AppExeption = AppException;
