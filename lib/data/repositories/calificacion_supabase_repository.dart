import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/calificacion.dart';
import 'package:yogo_vital_app/core/models/promedio_calificacion.dart';

class CalificacionSupabaseException implements Exception {
  final String message;
  final int? statusCode;
  const CalificacionSupabaseException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Reseñas de un prediseñado: promedio, total y las más recientes.
class ResenasPredisenhado {
  final double promedio;
  final int total;
  final List<Map<String, dynamic>> resenas;

  const ResenasPredisenhado({
    required this.promedio,
    required this.total,
    required this.resenas,
  });

  const ResenasPredisenhado.vacio()
      : promedio = 0,
        total = 0,
        resenas = const [];

  bool get sinCalificaciones => total == 0;
}

/// Repositorio para HU_CalificarPedido_30 — usa Supabase con RLS.
class CalificacionSupabaseRepository {
  SupabaseClient get _db => Supabase.instance.client;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) {
      throw const CalificacionSupabaseException('Usuario no autenticado');
    }
    return id;
  }

  /// Devuelve la calificación del pedido o null si no existe.
  Future<Calificacion?> getCalificacionPorPedido(String pedidoId) async {
    try {
      final data = await _db
          .from('calificaciones')
          .select()
          .eq('pedido_id', pedidoId)
          .maybeSingle();
      if (data == null) return null;
      return Calificacion.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// INSERT calificación. RLS garantiza que el pedido sea del cliente y esté Entregado.
  Future<Calificacion> enviarCalificacion({
    required String pedidoId,
    required int estrellas,
    String? comentario,
  }) async {
    try {
      final payload = <String, dynamic>{
        'pedido_id': pedidoId,
        'cliente_id': _uid,
        'estrellas': estrellas.clamp(1, 5),
        if (comentario != null && comentario.trim().isNotEmpty)
          'comentario': comentario.trim(),
      };
      final data = await _db
          .from('calificaciones')
          .insert(payload)
          .select()
          .single();
      return Calificacion.fromJson(data);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const CalificacionSupabaseException(
          'Ya calificaste este pedido.',
          statusCode: 409,
        );
      }
      if (e.code == '42501' || e.message.contains('violates row')) {
        throw const CalificacionSupabaseException(
          'Solo puedes calificar pedidos entregados.',
          statusCode: 403,
        );
      }
      throw CalificacionSupabaseException(
          'No se pudo guardar la calificación: ${e.message}');
    }
  }

  /// Promedio de estrellas de un sabor calculado desde calificaciones.
  Future<double> getPromedioEstrellasPorSabor(String saborId) async {
    try {
      final pedidosData = await _db
          .from('pedidos')
          .select('id')
          .eq('sabor_id', saborId);

      final pedidoIds = (pedidosData as List)
          .map((e) => e['id'] as String)
          .toList();
      if (pedidoIds.isEmpty) return 0.0;

      final calData = await _db
          .from('calificaciones')
          .select('estrellas')
          .inFilter('pedido_id', pedidoIds);

      final list = calData as List;
      if (list.isEmpty) return 0.0;

      final sum = list.fold<double>(
        0,
        (acc, e) => acc + ((e['estrellas'] as num).toDouble()),
      );
      return sum / list.length;
    } catch (_) {
      return 0.0;
    }
  }

  /// Reseñas de un prediseñado: promedio, total y las [limite] más recientes.
  ///
  /// Las calificaciones cuelgan de `pedido_id`, no del producto. Para los
  /// sabores el vínculo es `pedidos.sabor_id`; para los prediseñados es
  /// `pedidos.predisenhado_id`, columna añadida en la migración 0043. No
  /// hace falta ninguna tabla ni columna nueva.
  ///
  /// Ojo: solo cuentan los pedidos creados a partir de esa migración. Los
  /// anteriores no guardaban qué prediseñado se pidió, así que sus
  /// calificaciones (si las hay) no pueden atribuirse a ninguno.
  Future<ResenasPredisenhado> getResenasPorPredisenhado(
    String predisenhadoId, {
    int limite = 5,
  }) async {
    if (predisenhadoId.isEmpty) return const ResenasPredisenhado.vacio();
    try {
      final pedidosData = await _db
          .from('pedidos')
          .select('id')
          .eq('predisenhado_id', predisenhadoId);

      final pedidoIds =
          (pedidosData as List).map((e) => e['id'] as String).toList();
      if (pedidoIds.isEmpty) return const ResenasPredisenhado.vacio();

      // Todas las estrellas, para el promedio y el conteo real.
      final todas = await _db
          .from('calificaciones')
          .select('estrellas')
          .inFilter('pedido_id', pedidoIds);

      final listaTodas = todas as List;
      if (listaTodas.isEmpty) return const ResenasPredisenhado.vacio();

      final suma = listaTodas.fold<double>(
        0,
        (acc, e) => acc + ((e['estrellas'] as num).toDouble()),
      );
      final promedio = suma / listaTodas.length;

      // Solo las más recientes para mostrar en pantalla.
      final recientes = await _db
          .from('calificaciones')
          .select('estrellas, comentario, created_at')
          .inFilter('pedido_id', pedidoIds)
          .order('created_at', ascending: false)
          .limit(limite);

      return ResenasPredisenhado(
        promedio: double.parse(promedio.toStringAsFixed(1)),
        total: listaTodas.length,
        resenas: (recientes as List).cast<Map<String, dynamic>>(),
      );
    } catch (_) {
      return const ResenasPredisenhado.vacio();
    }
  }

  /// Promedios de TODOS los sabores calculados desde calificaciones.
  /// Retorna Map[saborId, PromedioCalificacion].
  Future<Map<String, PromedioCalificacion>> getPromediosPorSabores() async {
    try {
      final calData = await _db
          .from('calificaciones')
          .select('estrellas, pedido_id');

      if ((calData as List).isEmpty) return {};

      final pedidoIds = calData
          .map((e) => e['pedido_id'] as String)
          .toList();

      final pedidosData = await _db
          .from('pedidos')
          .select('id, sabor_id')
          .inFilter('id', pedidoIds);

      final Map<String, String> pedidoSabor = {
        for (final p in (pedidosData as List))
          p['id'] as String: p['sabor_id'] as String? ?? '',
      };

      final Map<String, List<int>> grouped = {};
      for (final item in calData) {
        final pedidoId = item['pedido_id'] as String;
        final saborId = pedidoSabor[pedidoId] ?? '';
        if (saborId.isEmpty) continue;
        grouped.putIfAbsent(saborId, () => []).add(item['estrellas'] as int);
      }

      return grouped.map((saborId, estrellas) {
        final avg =
            estrellas.fold<double>(0, (a, b) => a + b) / estrellas.length;
        return MapEntry(
          saborId,
          PromedioCalificacion(
            saborId: saborId,
            promedio: double.parse(avg.toStringAsFixed(1)),
            total: estrellas.length,
          ),
        );
      });
    } catch (_) {
      return {};
    }
  }
}
