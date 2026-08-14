import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/services/push_service.dart';
import 'package:yogo_vital_app/data/datasources/auth_remote_datasource.dart';

class AuthRepository {
  final AuthRemoteDataSource remote;

  AuthRepository({required this.remote});

  Future<AuthResponse> login(String email, String password) =>
      remote.signIn(email: email, password: password);

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) =>
      remote.signUp(name: name, email: email, phone: phone, password: password);

  Future<void> resetPassword(String email) =>
      remote.resetPasswordForEmail(email);

  /// Cierra sesión.
  ///
  /// Da de baja el dispositivo ANTES de cerrar, no después: una vez cerrada
  /// la sesión `auth.uid()` es null y la RPC que borra el token no sabría a
  /// quién pertenece. Si no se borrara, quien iniciara sesión después en
  /// este mismo teléfono recibiría las notificaciones de la cuenta anterior.
  Future<void> logout() async {
    await PushService.instance.darDeBaja();
    await remote.signOut();
  }

  Future<bool> signInWithGoogle() => remote.signInWithGoogle();

  Future<void> ensureUsuarioExists(User user) =>
      remote.ensureUsuarioExists(user);

  User? get currentUser => remote.currentUser;

  Stream<AuthState> get onAuthStateChange => remote.onAuthStateChange;

  Future<bool> isEmailRegistered(String email) =>
      remote.isEmailRegistered(email);
}
