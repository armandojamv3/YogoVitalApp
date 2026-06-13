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

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _httpClient.put(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeResponse(resp);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final resp = await _httpClient.delete(_uri(path));
    return _decodeResponse(resp);
  }

  /// PATCH para actualizaciones parciales (ej: cancelar pedido)
  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _httpClient.patch(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeResponse(resp);
  }

  /// Versión de GET que puede devolver List o Map (útil para colecciones)
  Future<dynamic> getDynamic(
    String path, {
    Map<String, String>? headers,
  }) async {
    final resp = await _httpClient.get(_uri(path), headers: headers);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.body.isEmpty ? [] : jsonDecode(resp.body);
    }
    throw ApiException(
      statusCode: resp.statusCode,
      body: {'error': resp.body},
    );
  }

  // Métodos de Negocio (Sprints)
  Future<Map<String, dynamic>> login(String email, String password) async {
    return await post('/api/login', {'email': email, 'password': password});
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    return await post('/api/register', userData);
  }

  Future<Map<String, dynamic>> getProducts() async {
    return await get('/api/products');
  }

  Future<Map<String, dynamic>> getFlavors() async {
    return await get('/api/flavors');
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    return await post('/api/orders', orderData);
  }

  Future<Map<String, dynamic>> getOrderHistory(int userId) async {
    return await get('/api/orders/user/$userId');
  }

  Future<Map<String, dynamic>> updateOrderStatus(int orderId, String status) async {
    return await put('/api/orders/$orderId/status', {'status': status});
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
