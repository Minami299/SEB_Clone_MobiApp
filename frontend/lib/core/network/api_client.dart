import 'dart:convert';
import 'package:http/http.dart' as http;
import '../error/exceptions.dart';
import '../services/session_service.dart';

class ApiClient {
  final http.Client client;

  ApiClient({http.Client? client}) : client = client ?? http.Client();

  Map<String, String> _buildHeaders(Map<String, String>? customHeaders) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = SessionService().token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  Future<dynamic> get(String url, {Map<String, String>? headers}) async {
    try {
      final response = await client.get(
        Uri.parse(url),
        headers: _buildHeaders(headers),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        final message = data is Map && data.containsKey('message')
            ? data['message']
            : 'Status code: ${response.statusCode}';
        throw ServerException(message);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<dynamic> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      final response = await client.post(
        Uri.parse(url),
        headers: _buildHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        final message = data is Map && data.containsKey('message')
            ? data['message']
            : 'Status code: ${response.statusCode}';
        throw ServerException(message);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<dynamic> patch(
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      final response = await client.patch(
        Uri.parse(url),
        headers: _buildHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      );

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        final message = data is Map && data.containsKey('message')
            ? data['message']
            : 'Status code: ${response.statusCode}';
        throw ServerException(message);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<dynamic> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await client.delete(
        Uri.parse(url),
        headers: _buildHeaders(headers),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        final message = data is Map && data.containsKey('message')
            ? data['message']
            : 'Status code: ${response.statusCode}';
        throw ServerException(message);
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException(e.toString());
    }
  }
}
