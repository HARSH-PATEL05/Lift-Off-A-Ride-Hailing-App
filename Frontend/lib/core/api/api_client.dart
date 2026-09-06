import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';
import 'package:flutter/foundation.dart';

/// LiftOff — API Client
/// Singleton HTTP client that auto-injects Supabase JWT into every
/// request sent to the FastAPI backend.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _httpClient = http.Client();

  /// Get the current Supabase JWT access token.
  /// Throws [UnauthorizedException] if no active session.
  String _getAccessToken() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw const UnauthorizedException();
    }
    return session.accessToken;
  }

  /// Build headers with JWT authorization.
  Map<String, String> _buildHeaders({Map<String, String>? extra}) {
    final token = _getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      if (extra != null) ...extra,
    };
  }

  /// Build full URL from endpoint path.
  Uri _buildUri(String endpoint, {Map<String, String>? queryParams}) {
    return Uri.parse('${ApiEndpoints.baseUrl}$endpoint').replace(
      queryParameters: queryParams?.isNotEmpty == true ? queryParams : null,
    );
  }

  /// Parse response and handle errors.
  dynamic _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    switch (response.statusCode) {
      case 200:
      case 201:
        return body;
      case 401:
        throw const UnauthorizedException();
      case 422:
        final message = body is Map
            ? (body['detail']?.toString() ?? 'Validation error')
            : 'Validation error';
        throw ValidationException(message: message);
      case >= 500:
        throw const ServerException();
      default:
        throw ApiException(
          message: body is Map
              ? (body['detail']?.toString() ?? 'Request failed')
              : 'Request failed',
          statusCode: response.statusCode,
          responseBody: body,
        );
    }
  }

  // ─── HTTP Methods ───

  /// GET request to FastAPI backend.
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final response = await _httpClient.get(
        _buildUri(endpoint, queryParams: queryParams),
        headers: _buildHeaders(),
      );
      return _handleResponse(response);
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }
  }

  /// POST request to FastAPI backend.
  // Future<dynamic> post(
  //   String endpoint, {
  //   Map<String, dynamic>? body,
  // }) async {
  //   try {
  //     final response = await _httpClient.post(
  //       _buildUri(endpoint),
  //       headers: _buildHeaders(),
  //       body: body != null ? jsonEncode(body) : null,
  //     );
  //     return _handleResponse(response);
  //   } on SocketException {
  //     throw const NetworkException();
  //   } on http.ClientException {
  //     throw const NetworkException();
  //   }
  // }
  Future<dynamic> post(
  String endpoint, {
  Map<String, dynamic>? body,
}) async {
  try {
    final uri = _buildUri(endpoint);

    debugPrint('');
    debugPrint('========== HTTP POST REQUEST ==========');
    debugPrint('URL: $uri');
    debugPrint('Endpoint: $endpoint');

    final token = _getAccessToken();
    debugPrint('JWT exists: ${token.isNotEmpty}');
    debugPrint('JWT length: ${token.length}');

    final response = await _httpClient.post(
      uri,
      headers: _buildHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );

    debugPrint('========== HTTP RESPONSE ==========');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Body: ${response.body}');
    debugPrint('===================================');

    return _handleResponse(response);

  } on SocketException catch (e) {
    debugPrint('❌ SOCKET EXCEPTION');
    debugPrint(e.toString());
    throw const NetworkException();

  } on http.ClientException catch (e) {
    debugPrint('❌ HTTP CLIENT EXCEPTION');
    debugPrint(e.toString());
    throw const NetworkException();

  } catch (e) {
    debugPrint('❌ UNKNOWN API ERROR');
    debugPrint(e.toString());
    rethrow;
  }
}

  /// PUT request to FastAPI backend.
  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await _httpClient.put(
        _buildUri(endpoint),
        headers: _buildHeaders(),
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }
  }
}
