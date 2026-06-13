import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) =>
      _client.auth.signUp(
        email: email,
        password: password,
        data: {'nombre': name, 'telefono': phone},
      );

  Future<void> resetPasswordForEmail(String email) =>
      _client.auth.resetPasswordForEmail(email);

  Future<void> signOut() => _client.auth.signOut();

  Future<bool> signInWithGoogle() => _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo:
            kIsWeb ? null : 'io.supabase.yogovital://login-callback',
      );

  Future<void> ensureUsuarioExists(User user) async {
    final existing = await _client
        .from('usuarios')
        .select('id, nombre')
        .eq('id', user.id)
        .maybeSingle();

    if (existing == null) {
      final nombre = user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String? ??
          '';
      await _client.from('usuarios').insert({
        'id': user.id,
        'nombre': nombre,
        'correo': user.email ?? '',
        'rol': 'cliente',
      });
    } else if ((existing['nombre'] as String?)?.isEmpty ?? true) {
      // Row created by trigger but nombre came empty (Google doesn't set 'nombre')
      final nombre = user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String? ??
          '';
      if (nombre.isNotEmpty) {
        await _client
            .from('usuarios')
            .update({'nombre': nombre})
            .eq('id', user.id);
      }
    }
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Queries the 'usuarios' table via RPC to check if the email is taken.
  /// Requires the SQL function 'check_email_exists' to exist in Supabase.
  Future<bool> isEmailRegistered(String email) async {
    try {
      final result = await _client
          .rpc('check_email_exists', params: {'email_to_check': email});
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }
}
