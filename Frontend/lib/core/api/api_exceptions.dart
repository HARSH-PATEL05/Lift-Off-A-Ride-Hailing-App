/// LiftOff — API Exception Hierarchy
/// Typed exceptions for clean error handling in services and UI.

/// Base exception for all API errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic responseBody;

  const ApiException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 401 — JWT expired or invalid.
class UnauthorizedException extends ApiException {
  const UnauthorizedException({String message = 'Session expired. Please sign in again.'})
      : super(message: message, statusCode: 401);
}

/// No internet or server unreachable.
class NetworkException extends ApiException {
  const NetworkException({String message = 'Unable to connect. Check your internet connection.'})
      : super(message: message, statusCode: null);
}

/// 422 — Validation error from FastAPI.
class ValidationException extends ApiException {
  const ValidationException({required String message})
      : super(message: message, statusCode: 422);
}

/// 500 — Server error.
class ServerException extends ApiException {
  const ServerException({String message = 'Something went wrong. Please try again.'})
      : super(message: message, statusCode: 500);
}
