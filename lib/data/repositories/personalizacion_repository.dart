import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/extra.dart';
import 'package:yogo_vital_app/core/models/fruta.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/core/models/tamano_model.dart';
import 'package:yogo_vital_app/data/local/local_database.dart';

/// Catálogo de personalización. Fuente de verdad: Supabase/PostgreSQL en
/// la nube. Cada consulta intenta la red primero y guarda una copia en
/// la caché local (SQLite); si la red falla (sin internet), se lee esa
/// copia en su lugar para que la pantalla de personalización no se
/// quede en blanco.
class PersonalizacionRepository {
  SupabaseClient get _client => Supabase.instance.client;
  final _localDb = LocalDatabase.instance;

  // HU_10: tamaños disponibles ordenados por precio
  Future<List<TamanoModel>> getTamanos() async {
    try {
      final data = await _client
          .from('tamanos_yogur')
          .select()
          .order('precio', ascending: true);
      final rows = (data as List).cast<Map<String, dynamic>>();
      // No se espera (fire-and-forget): guardar el caché nunca debe
      // demorar ni bloquear la respuesta que ya llegó de Supabase.
      unawaited(_localDb.replaceAll('tamanos', rows));
      return rows.map(TamanoModel.fromJson).toList();
    } catch (e) {
      debugPrint('[Personalizacion] Sin red para tamanos, usando caché: $e');
      final cached = await _localDb.getAll('tamanos');
      if (cached.isEmpty) rethrow;
      return cached.map(TamanoModel.fromJson).toList();
    }
  }

  // HU_12: sabores activos para selección
  Future<List<Sabor>> getSabores() async {
    try {
      final data = await _client
          .from('sabores')
          .select()
          .eq('activo', true)
          .order('nombre');
      final rows = (data as List).cast<Map<String, dynamic>>();
      unawaited(_localDb.replaceAll('sabores', rows));
      return rows.map(Sabor.fromJson).toList();
    } catch (e) {
      debugPrint('[Personalizacion] Sin red para sabores, usando caché: $e');
      final cached = await _localDb.getAll('sabores');
      if (cached.isEmpty) rethrow;
      return cached.map(_boolFromSqlite(['activo'])).map(Sabor.fromJson).toList();
    }
  }

  // HU_14: frutas disponibles para agregar
  Future<List<Fruta>> getFrutas() async {
    try {
      final data = await _client
          .from('frutas')
          .select()
          .eq('disponible', true)
          .order('nombre');
      final rows = (data as List).cast<Map<String, dynamic>>();
      unawaited(_localDb.replaceAll('frutas', rows));
      return rows.map(Fruta.fromJson).toList();
    } catch (e) {
      debugPrint('[Personalizacion] Sin red para frutas, usando caché: $e');
      final cached = await _localDb.getAll('frutas');
      if (cached.isEmpty) rethrow;
      return cached.map(_boolFromSqlite(['disponible'])).map(Fruta.fromJson).toList();
    }
  }

  // HU_16: extras disponibles
  Future<List<Extra>> getExtras() async {
    try {
      final data = await _client
          .from('extras')
          .select()
          .eq('disponible', true)
          .order('nombre');
      final rows = (data as List).cast<Map<String, dynamic>>();
      unawaited(_localDb.replaceAll('extras', rows));
      return rows.map(Extra.fromJson).toList();
    } catch (e) {
      debugPrint('[Personalizacion] Sin red para extras, usando caché: $e');
      final cached = await _localDb.getAll('extras');
      if (cached.isEmpty) rethrow;
      return cached.map(_boolFromSqlite(['disponible'])).map(Extra.fromJson).toList();
    }
  }

  /// SQLite guarda los booleanos como 0/1; los *.fromJson de los modelos
  /// esperan `bool`. Este helper convierte de vuelta antes de parsear.
  Map<String, dynamic> Function(Map<String, dynamic>) _boolFromSqlite(
      List<String> campos) {
    return (row) {
      final copia = Map<String, dynamic>.from(row);
      for (final campo in campos) {
        if (copia[campo] is int) copia[campo] = copia[campo] == 1;
      }
      return copia;
    };
  }
}
