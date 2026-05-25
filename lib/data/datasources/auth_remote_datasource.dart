import 'package:yogo_vital_app/core/network/api_client.dart';

class AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSource({required this.apiClient});

  /// Register user. Returns server response map.
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? passwordConfirmation,
  }) async {
    final body = {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
    };
    if (passwordConfirmation != null) {
      body['password_confirmation'] = passwordConfirmation;
    }
    return apiClient.post('/auth/register', body);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    return apiClient.post('/auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> resendVerification({
    required String email,
  }) async {
    return apiClient.post('/auth/resend_verification', {'email': email});
  }

  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    return apiClient.post('/auth/password_reset', {'email': email});
  }

  Future<Map<String, dynamic>> confirmPasswordReset({
    required String token,
    required String password,
    String? passwordConfirmation,
  }) async {
    final body = {'token': token, 'password': password};
    if (passwordConfirmation != null) {
      body['password_confirmation'] = passwordConfirmation;
    }
    return apiClient.post('/auth/password_reset/confirm', body);
  }

  Future<Map<String, dynamic>> verify({required String token}) async {
    return apiClient.get('/auth/verify?token=$token');
  }
}
