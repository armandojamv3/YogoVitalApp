import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  /// A dónde debe volver el usuario al pulsar el enlace de un correo de
  /// Supabase (confirmación de cuenta, recuperación de contraseña) o al
  /// terminar el login con Google.
  ///
  /// En móvil es el deep link declarado en AndroidManifest.xml y en
  /// Info.plist. En web se deja en null para que Supabase use el Site URL
  /// del proyecto, que ahí sí es una URL normal.
  ///
  /// Se usa el mismo host (`login-callback`) para los tres casos a
  /// propósito: así basta un intent-filter y una entrada en la lista de
  /// Redirect URLs del dashboard. Lo que distingue un flujo de otro es el
  /// evento que emite Supabase al abrirlo (signedIn vs passwordRecovery),
  /// no la URL.
  static const String deepLinkCallback =
      'io.supabase.yogovital://login-callback';

  static String? get _redirect => kIsWeb ? null : deepLinkCallback;

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
        // Sin esto el enlace de "confirma tu cuenta" apuntaba al Site URL
        // por defecto del proyecto (http://localhost:3000) y no abría la app.
        emailRedirectTo: _redirect,
      );

  Future<void> resetPasswordForEmail(String email) =>
      _client.auth.resetPasswordForEmail(email, redirectTo: _redirect);

  Future<void> signOut() => _client.auth.signOut();

  Future<bool> signInWithGoogle() => _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirect,
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
