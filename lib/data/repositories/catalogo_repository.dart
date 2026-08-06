import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/core/models/predisenhado_model.dart';

class CatalogoRepository {
  SupabaseClient get _client => Supabase.instance.client;

  // HU_07: últimos 10 sabores activos para el Home
  Future<List<Sabor>> getSaboresHome({int limit = 10}) async {
    try {
      final data = await _client
          .from('sabores')
          .select()
          .eq('activo', true)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List)
          .map((e) => Sabor.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Supabase [${e.code}]: ${e.message}');
    }
  }

  // HU_08: catálogo completo de sabores ordenados por nombre
  Future<List<Sabor>> getCatalogSabores() async {
    try {
      final data = await _client
          .from('sabores')
          .select()
          .eq('activo', true)
          .order('nombre');
      return (data as List)
          .map((e) => Sabor.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Supabase [${e.code}]: ${e.message}');
    }
  }

  // Búsqueda de sabores por nombre (barra de lupa en Home / Yogures)
  Future<List<Sabor>> buscarSabores(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final data = await _client
          .from('sabores')
          .select()
          .eq('activo', true)
          .ilike('nombre', '%$q%')
          .order('nombre')
          .limit(20);
      return (data as List)
          .map((e) => Sabor.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Supabase [${e.code}]: ${e.message}');
    }
  }

  // HU_09: prediseñados activos
  Future<List<PredisenhadoModel>> getPredisenhados() async {
    try {
      final data = await _client
          .from('predisenhados')
          .select()
          .eq('activo', true);
      return (data as List)
          .map((e) => PredisenhadoModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
