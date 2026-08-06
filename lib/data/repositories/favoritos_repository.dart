import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';

/// Favoritos del cliente (sabores marcados con el corazón).
class FavoritosRepository {
  SupabaseClient get _db => Supabase.instance.client;

  String? get _uid => _db.auth.currentUser?.id;

  /// Stream con los ids de sabores favoritos del cliente autenticado.
  /// Se usa para pintar el corazón lleno/vacío en tiempo real.
  Stream<Set<String>> streamFavoritoIds() {
    final uid = _uid;
    if (uid == null) return Stream.value(const {});
    return _db
        .from('favoritos')
        .stream(primaryKey: ['id'])
        .eq('cliente_id', uid)
        .map((rows) =>
            rows.map((r) => r['sabor_id'].toString()).toSet());
  }

  /// Consulta puntual (no-stream) de si un sabor es favorito del cliente.
  /// Se usa para el estado inicial del botón de corazón en las tarjetas.
  Future<bool> isFavorito(String saborId) async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _db
        .from('favoritos')
        .select('id')
        .eq('cliente_id', uid)
        .eq('sabor_id', saborId)
        .maybeSingle();
    return row != null;
  }

  /// Alterna el estado de favorito de un sabor. Devuelve el nuevo estado
  /// (true = quedó como favorito, false = se quitó).
  Future<bool> toggle(String saborId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    final existente = await _db
        .from('favoritos')
        .select('id')
        .eq('cliente_id', uid)
        .eq('sabor_id', saborId)
        .maybeSingle();

    if (existente != null) {
      await _db.from('favoritos').delete().eq('id', existente['id']);
      return false;
    } else {
      await _db.from('favoritos').insert({
        'cliente_id': uid,
        'sabor_id': saborId,
      });
      return true;
    }
  }

  /// Sabores favoritos del cliente, con todos sus datos (para la pantalla
  /// "Tus Favoritos").
  Future<List<Sabor>> getFavoritosConDetalle() async {
    final uid = _uid;
    if (uid == null) return [];
    final data = await _db
        .from('favoritos')
        .select('sabores(*)')
        .eq('cliente_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) => row['sabores'])
        .whereType<Map<String, dynamic>>()
        .map(Sabor.fromJson)
        .toList();
  }
}
