import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:yogo_vital_app/data/datasources/auth_remote_datasource.dart';

class AuthRepository {
  final AuthRemoteDataSource remote;
  final FlutterSecureStorage storage;
  static const _jwtKey = 'jwt_token';

  AuthRepository({required this.remote, FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password, {
    String? passwordConfirmation,
  }) async {
    return remote.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await remote.login(email: email, password: password);
    final token = res['token'] as String?;
    if (token != null) {
      await storage.write(key: _jwtKey, value: token);
    }
    return res;
  }

  Future<Map<String, dynamic>> resendVerification(String email) async {
    return remote.resendVerification(email: email);
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    return remote.requestPasswordReset(email: email);
  }

  Future<Map<String, dynamic>> confirmPasswordReset({
    required String token,
    required String password,
    String? passwordConfirmation,
  }) async {
    return remote.confirmPasswordReset(
      token: token,
      password: password,
      passwordConfirmation: passwordConfirmation,
    );
  }

  Future<void> logout() async {
    await storage.delete(key: _jwtKey);
  }

  Future<String?> getToken() async => await storage.read(key: _jwtKey);
}
