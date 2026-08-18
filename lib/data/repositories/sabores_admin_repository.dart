import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';

class SaboresAdminException implements Exception {
  final String message;
  final int? statusCode;
  const SaboresAdminException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Repositorio Supabase para CRUD de sabores en el módulo admin (Sprint 6).
/// RLS garantiza que solo el administrador puede escribir.
class SaboresAdminRepository {
  SupabaseClient get _db => Supabase.instance.client;

  // ── READ ────────────────────────────────────────────────────────────────

  Future<List<Sabor>> getSabores() async {
    try {
      final data = await _db
          .from('sabores')
          .select()
          .order('nombre', ascending: true);
      return (data as List).map((e) => Sabor.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw SaboresAdminException('No se pudo cargar los sabores: ${e.message}');
    }
  }

  // ── IMAGEN ── sube la foto a Supabase Storage y devuelve la URL pública ──

  Future<String> uploadImagen(Uint8List bytes, String fileName) async {
    try {
      // El nombre que entrega la galería/selector (picked.name) puede traer
      // espacios, acentos o paréntesis (p.ej. "Screenshot 2024 (1).png").
      // Eso genera una URL pública mal formada y CachedNetworkImage se
      // queda colgado en el placeholder en vez de mostrar error (bug
      // conocido en Flutter Web). Por eso generamos un nombre seguro,
      // conservando solo la extensión original del archivo.
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final safeExt =
          RegExp(r'^[a-zA-Z0-9]+$').hasMatch(ext) ? ext.toLowerCase() : 'jpg';
      final path = '${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      await _db.storage.from('sabores').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _db.storage.from('sabores').getPublicUrl(path);
    } on StorageException catch (e) {
      throw SaboresAdminException('No se pudo subir la imagen: ${e.message}');
    }
  }

  // ── CREATE ── HU_AgregarSabor_32 ─────────────────────────────────────────

  Future<Sabor> createSabor({
    required String nombre,
    required String descripcion,
    required double recargo,
    String? imagenUrl,
  }) async {
    try {
      final data = await _db
          .from('sabores')
          .insert({
            'nombre': nombre.trim(),
            'descripcion': descripcion.trim(),
            'recargo': recargo,
            'activo': true,
            if (imagenUrl != null) 'imagen_url': imagenUrl,
          })
          .select()
          .single();
      return Sabor.fromJson(data);
    } on PostgrestException catch (e) {
      throw _mapPostgrestError(e);
    }
  }

  // ── UPDATE ── HU_EditarSabor_33 ──────────────────────────────────────────

  Future<Sabor> updateSabor({
    required String id,
    required String nombre,
    required String descripcion,
    required double recargo,
    String? imagenUrl,
  }) async {
    try {
      final data = await _db
          .from('sabores')
          .update({
            'nombre': nombre.trim(),
            'descripcion': descripcion.trim(),
            'recargo': recargo,
            if (imagenUrl != null) 'imagen_url': imagenUrl,
          })
          .eq('id', id)
          .select()
          .single();
      return Sabor.fromJson(data);
    } on PostgrestException catch (e) {
      throw _mapPostgrestError(e);
    }
  }

  // ── DELETE ── HU_EliminarSabor_34 (soft-delete) ──────────────────────────

  Future<void> deleteSabor(String id) async {
    try {
      await _db
          .from('sabores')
          .update({'activo': false})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw _mapPostgrestError(e);
    }
  }

  // ── VERIFICAR pedidos activos antes de eliminar ───────────────────────────

  Future<bool> tienePedidosActivos(String saborId) async {
    try {
      final data = await _db
          .from('pedidos')
          .select('id')
          .eq('sabor_id', saborId)
          .not('estado', 'in', '(Entregado,Cancelado)');
      return (data as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Helper ───────────────────────────────────────────────────────────────

  SaboresAdminException _mapPostgrestError(PostgrestException e) {
    if (e.code == '42501' || e.message.contains('row-level security')) {
      return const SaboresAdminException(
          'No tienes permiso para realizar esta acción.', statusCode: 403);
    }
    if (e.code == '23505') {
      return const SaboresAdminException(
          'Ya existe un sabor con ese nombre.', statusCode: 409);
    }
    return SaboresAdminException(
        'Error en la base de datos: ${e.message}');
  }
}
