import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;

  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Uri _uri(String path) => Uri.parse(baseUrl + path);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _httpClient.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeResponse(resp);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final resp = await _httpClient.get(_uri(path), headers: headers);
    return _decodeResponse(resp);
  }

  Map<String, dynamic> _decodeResponse(http.Response resp) {
    try {
      final decoded = resp.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(resp.body);
      final Map<String, dynamic> body;
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else {
        body = {'data': decoded};
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return body;
      }
      throw ApiException(statusCode: resp.statusCode, body: body);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: resp.statusCode,
        body: {'error': e.toString()},
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final Map<String, dynamic> body;
  ApiException({required this.statusCode, required this.body});

  @override
  String toString() => 'ApiException($statusCode): $body';
}
