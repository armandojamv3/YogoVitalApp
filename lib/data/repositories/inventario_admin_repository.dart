import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/extra.dart';
import 'package:yogo_vital_app/core/models/fruta.dart';

class InventarioException implements Exception {
  final String message;
  const InventarioException(this.message);
  @override
  String toString() => message;
}

/// Repositorio Supabase para CRUD + Realtime de frutas y extras (Sprint 7).
/// Las streams actualizan la UI en tiempo real (RNF03 ISO 25010).
class InventarioAdminRepository {
  SupabaseClient get _db => Supabase.instance.client;

  // ── STREAMS (Realtime) ────────────────────────────────────────────────────

  Stream<List<Fruta>> streamFrutas() {
    return _db
        .from('frutas')
        .stream(primaryKey: ['id'])
        .order('nombre', ascending: true)
        .map((data) => data.map(Fruta.fromJson).toList());
  }

  Stream<List<Extra>> streamExtras() {
    return _db
        .from('extras')
        .stream(primaryKey: ['id'])
        .order('nombre', ascending: true)
        .map((data) => data.map(Extra.fromJson).toList());
  }

  // ── FRUTAS CRUD ───────────────────────────────────────────────────────────

  Future<void> createFruta({
    required String nombre,
    required double precioAdicional,
  }) async {
    try {
      await _db.from('frutas').insert({
        'nombre': nombre.trim(),
        'precio_adicional': precioAdicional,
        'disponible': true,
      });
    } on PostgrestException catch (e) {
      throw InventarioException(_mapError(e, 'fruta'));
    }
  }

  Future<void> updateFruta({
    required String id,
    required String nombre,
    required double precioAdicional,
  }) async {
    try {
      await _db.from('frutas').update({
        'nombre': nombre.trim(),
        'precio_adicional': precioAdicional,
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw InventarioException(_mapError(e, 'fruta'));
    }
  }

  Future<void> toggleDisponibilidadFruta(
      String id, {required bool disponible}) async {
    try {
      await _db
          .from('frutas')
          .update({'disponible': disponible})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw InventarioException(_mapError(e, 'fruta'));
    }
  }

  Future<void> deleteFruta(String id) async {
    try {
      await _db
          .from('frutas')
          .update({'disponible': false})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw InventarioException(_mapError(e, 'fruta'));
    }
  }

  // ── EXTRAS CRUD ───────────────────────────────────────────────────────────

  Future<void> createExtra({
    required String nombre,
    required double precioAdicional,
  }) async {
    try {
      await _db.from('extras').insert({
        'nombre': nombre.trim(),
        'precio_adicional': precioAdicional,
        'disponible': true,
      });
    } on PostgrestException catch (e) {
      throw InventarioException(_mapError(e, 'extra'));
    }
  }

  Future<void> updateExtra({
    required String id,
    required String nombre,
    required double precioAdicional,
  }) async {
    try {
      await _db.from('extras').update({
        'nombre': nombre.trim(),
        'precio_adicional': precioAdicional,
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw InventarioException(_mapError(e, 'extra'));
    }
  }

  Future<void> toggleDisponibilidadExtra(
      String id, {required bool disponible}) async {
    try {
      await _db
          .from('extras')
          .update({'disponible': disponible})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw InventarioException(_mapError(e, 'extra'));
    }
  }

  Future<void> deleteExtra(String id) async {
    try {
      await _db
          .from('extras')
          .update({'disponible': false})
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw InventarioException(_mapError(e, 'extra'));
    }
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  String _mapError(PostgrestException e, String entidad) {
    if (e.code == '42501' || e.message.contains('row-level security')) {
      return 'No tienes permiso para modificar ${entidad}s.';
    }
    if (e.code == '23505') {
      return 'Ya existe un(a) $entidad con ese nombre.';
    }
    return 'Error en la base de datos: ${e.message}';
  }
}
