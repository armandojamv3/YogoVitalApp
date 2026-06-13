import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio de verificación de rol — RNF08 (ISO 27001).
/// Solo usa la tabla `usuarios`; nunca expone datos sensibles.
class UserRoleService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<String> getRole() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return 'cliente';
    try {
      final data = await _db
          .from('usuarios')
          .select('rol')
          .eq('id', uid)
          .single();
      return data['rol'] as String? ?? 'cliente';
    } catch (_) {
      return 'cliente';
    }
  }

  static Future<bool> isAdmin() async =>
      (await getRole()) == 'administrador';
}
