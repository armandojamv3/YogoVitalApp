import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<void> logout() => remote.signOut();

  Future<bool> signInWithGoogle() => remote.signInWithGoogle();

  Future<void> ensureUsuarioExists(User user) =>
      remote.ensureUsuarioExists(user);

  User? get currentUser => remote.currentUser;

  Stream<AuthState> get onAuthStateChange => remote.onAuthStateChange;

  Future<bool> isEmailRegistered(String email) =>
      remote.isEmailRegistered(email);
}
