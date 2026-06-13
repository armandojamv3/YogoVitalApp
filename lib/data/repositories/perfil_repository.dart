import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/user_model.dart';

class PerfilException implements Exception {
  final String message;
  const PerfilException(this.message);
  @override
  String toString() => 'PerfilException: $message';
}

/// Repositorio para HU_GestionarPerfil_29.
/// Lee y actualiza la tabla `usuarios` del propio cliente.
class PerfilRepository {
  SupabaseClient get _db => Supabase.instance.client;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const PerfilException('Usuario no autenticado');
    return id;
  }

  Future<UserModel> getPerfil() async {
    try {
      final data = await _db
          .from('usuarios')
          .select('id, nombre, correo, telefono, rol')
          .eq('id', _uid)
          .single();
      return UserModel.fromJson(data);
    } catch (e) {
      throw PerfilException('No se pudo cargar el perfil: $e');
    }
  }

  Future<void> updatePerfil({
    required String nombre,
    required String telefono,
  }) async {
    try {
      await _db.from('usuarios').update({
        'nombre': nombre.trim(),
        'telefono': telefono.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _uid);
    } on PostgrestException catch (e) {
      throw PerfilException('No se pudo actualizar el perfil: ${e.message}');
    } catch (e) {
      throw PerfilException('Error inesperado: $e');
    }
  }
}
