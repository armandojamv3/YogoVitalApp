import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/extra.dart';
import 'package:yogo_vital_app/core/models/fruta.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/core/models/tamano_model.dart';

class PersonalizacionRepository {
  SupabaseClient get _client => Supabase.instance.client;

  // HU_10: tamaños disponibles ordenados por precio
  Future<List<TamanoModel>> getTamanos() async {
    final data = await _client
        .from('tamanos_yogur')
        .select()
        .order('precio', ascending: true);
    return (data as List)
        .map((e) => TamanoModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // HU_12: sabores activos para selección
  Future<List<Sabor>> getSabores() async {
    final data = await _client
        .from('sabores')
        .select()
        .eq('activo', true)
        .order('nombre');
    return (data as List)
        .map((e) => Sabor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // HU_14: frutas disponibles para agregar
  Future<List<Fruta>> getFrutas() async {
    final data = await _client
        .from('frutas')
        .select()
        .eq('disponible', true)
        .order('nombre');
    return (data as List)
        .map((e) => Fruta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // HU_16: extras disponibles
  Future<List<Extra>> getExtras() async {
    final data = await _client
        .from('extras')
        .select()
        .eq('disponible', true)
        .order('nombre');
    return (data as List)
        .map((e) => Extra.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
