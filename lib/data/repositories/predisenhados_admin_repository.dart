import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/predisenhado_model.dart';

class PredisenhadosAdminException implements Exception {
  final String message;
  final int? statusCode;
  const PredisenhadosAdminException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Repositorio Supabase para CRUD de prediseñados en el módulo admin.
/// RLS (migración 0015: admin_all_predisenhados) garantiza que solo el
/// administrador puede escribir; los clientes solo ven los activos.
class PredisenhadosAdminRepository {
  SupabaseClient get _db => Supabase.instance.client;

  // ── READ ────────────────────────────────────────────────────────────────

  Future<List<PredisenhadoModel>> getPredisenhados() async {
    try {
      final data = await _db
          .from('predisenhados')
          .select()
          .order('nombre', ascending: true);
      return (data as List)
          .map((e) => PredisenhadoModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw PredisenhadosAdminException(
          'No se pudo cargar los prediseñados: ${e.message}');
    }
  }

  // ── IMAGEN ── sube la foto a Supabase Storage y devuelve la URL pública ──

  Future<String> uploadImagen(Uint8List bytes, String fileName) async {
    try {
      // Mismo criterio que en sabores: nombre seguro para evitar URLs rotas
      // con espacios/acentos/paréntesis del nombre original del archivo.
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final safeExt =
          RegExp(r'^[a-zA-Z0-9]+$').hasMatch(ext) ? ext.toLowerCase() : 'jpg';
      final path = '${DateTime.now().millisecondsSinceEpoch}.$safeExt';
      await _db.storage.from('predisenhados').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _db.storage.from('predisenhados').getPublicUrl(path);
    } on StorageException catch (e) {
      throw PredisenhadosAdminException('No se pudo subir la imagen: ${e.message}');
    }
  }

  // ── CREATE ──────────────────────────────────────────────────────────────

  Future<PredisenhadoModel> createPredisenhado({
    required String nombre,
    required String descripcion,
    required List<String> ingredientes,
    required double precioTotal,
    String? imagenUrl,
    bool esPopular = false,
    bool esNuevo = false,
  }) async {
    try {
      final data = await _db
          .from('predisenhados')
          .insert({
            'nombre': nombre.trim(),
            'descripcion': descripcion.trim(),
            'ingredientes': ingredientes,
            'precio_total': precioTotal,
            'activo': true,
            'es_popular': esPopular,
            'es_nuevo': esNuevo,
            if (imagenUrl != null) 'imagen_url': imagenUrl,
          })
          .select()
          .single();
      return PredisenhadoModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw _mapPostgrestError(e);
    }
  }

  // ── UPDATE ──────────────────────────────────────────────────────────────

  Future<PredisenhadoModel> updatePredisenhado({
    required String id,
    required String nombre,
    required String descripcion,
    required List<String> ingredientes,
    required double precioTotal,
    String? imagenUrl,
    bool esPopular = false,
    bool esNuevo = false,
  }) async {
    try {
      final data = await _db
          .from('predisenhados')
          .update({
            'nombre': nombre.trim(),
            'descripcion': descripcion.trim(),
            'ingredientes': ingredientes,
            'precio_total': precioTotal,
            'es_popular': esPopular,
            'es_nuevo': esNuevo,
            if (imagenUrl != null) 'imagen_url': imagenUrl,
          })
          .eq('id', id)
          .select()
          .single();
      return PredisenhadoModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw _mapPostgrestError(e);
    }
  }

  // ── DELETE (soft-delete, igual que sabores) ──────────────────────────────

  Future<void> deletePredisenhado(String id) async {
    try {
      await _db
          .from('predisenhados')
          .update({'activo': false})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw _mapPostgrestError(e);
    }
  }

  // ── Helper ───────────────────────────────────────────────────────────────

  PredisenhadosAdminException _mapPostgrestError(PostgrestException e) {
    if (e.code == '42501' || e.message.contains('row-level security')) {
      return const PredisenhadosAdminException(
          'No tienes permiso para realizar esta acción.', statusCode: 403);
    }
    if (e.code == '23505') {
      return const PredisenhadosAdminException(
          'Ya existe un prediseñado con ese nombre.', statusCode: 409);
    }
    return PredisenhadosAdminException(
        'Error en la base de datos: ${e.message}');
  }
}
