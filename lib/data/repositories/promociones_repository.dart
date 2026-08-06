import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/promocion.dart';

class PromocionesException implements Exception {
  final String message;
  const PromocionesException(this.message);
  @override
  String toString() => message;
}

/// Promociones: el admin publica, el cliente lee. RLS garantiza que solo
/// el admin puede escribir (ver migración 0029).
class PromocionesRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// Todas las promociones (para el panel admin, activas e inactivas).
  Future<List<Promocion>> getTodas() async {
    try {
      final data = await _db
          .from('promociones')
          .select()
          .order('created_at', ascending: false);
      return (data as List).map((e) => Promocion.fromJson(e)).toList();
    } on PostgrestException catch (e) {
      throw PromocionesException('No se pudieron cargar las promociones: ${e.message}');
    }
  }

  /// Stream en tiempo real (para que el cliente vea nuevas promos sin
  /// recargar). El filtro de "vigente" se aplica en el cliente Dart.
  Stream<List<Promocion>> streamVigentes() {
    return _db
        .from('promociones')
        .stream(primaryKey: ['id'])
        .map((rows) {
          final list = rows.map(Promocion.fromJson).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list.where((p) => p.vigente).toList();
        });
  }

  Future<Promocion> crear({
    required String titulo,
    required String descripcion,
    required DateTime fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      final data = await _db
          .from('promociones')
          .insert(Promocion(
            id: '',
            titulo: titulo.trim(),
            descripcion: descripcion.trim(),
            fechaInicio: fechaInicio,
            fechaFin: fechaFin,
            activa: true,
            createdAt: DateTime.now(),
          ).toInsertJson())
          .select()
          .single();
      return Promocion.fromJson(data);
    } on PostgrestException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> actualizar({
    required String id,
    required String titulo,
    required String descripcion,
    required DateTime fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      await _db.from('promociones').update({
        'titulo': titulo.trim(),
        'descripcion': descripcion.trim(),
        'fecha_inicio': fechaInicio.toIso8601String(),
        'fecha_fin': fechaFin?.toIso8601String(),
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> toggleActiva(String id, bool activa) async {
    try {
      await _db.from('promociones').update({'activa': activa}).eq('id', id);
    } on PostgrestException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> eliminar(String id) async {
    try {
      await _db.from('promociones').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw _mapError(e);
    }
  }

  PromocionesException _mapError(PostgrestException e) {
    if (e.code == '42501' || e.message.contains('row-level security')) {
      return const PromocionesException(
          'No tienes permiso para realizar esta acción.');
    }
    return PromocionesException('Error en la base de datos: ${e.message}');
  }
}
