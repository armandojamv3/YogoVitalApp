import 'package:flutter/foundation.dart';
import 'package:yogo_vital_app/data/repositories/personalizacion_repository.dart';

/// Precio de partida de un yogur típico.
///
/// ── Por qué existe ────────────────────────────────────────────────────
/// Las tarjetas del catálogo mostraban `sabores.precio_base`, un número que
/// desde la migración 0051 ya no se cobra. El cliente veía $9.000 en la
/// lista y le aparecía otro precio al entrar.
///
/// Lo que se cobra de verdad es el precio del tamaño más el recargo del
/// sabor. Como en una tarjeta todavía no hay tamaño elegido, se muestra el
/// más barato con la palabra "Desde".
///
/// Ese mínimo es el mismo para toda la app y cambia muy de vez en cuando,
/// así que se pide una vez y se guarda. Sin esto, cada pantalla que enseña
/// tarjetas —Inicio, Yogures, Favoritos, búsqueda— repetiría la misma
/// consulta.
class PreciosService {
  PreciosService._();

  static final _repo = PersonalizacionRepository();

  static double? _tamanoMasBarato;
  static Future<void>? _enCurso;

  /// Precio del tamaño más barato, o null si todavía no se ha cargado.
  static double? get tamanoMasBarato => _tamanoMasBarato;

  /// Pide los tamaños y se queda con el más barato.
  ///
  /// Llamadas simultáneas comparten la misma petición: si Inicio y Yogures
  /// arrancan a la vez, no se consulta dos veces.
  ///
  /// [forzar] vuelve a consultar aunque ya hubiera un valor. Hace falta
  /// después de que un administrador cambie los precios de los tamaños.
  static Future<void> precargar({bool forzar = false}) {
    if (!forzar && _tamanoMasBarato != null) return Future.value();
    return _enCurso ??= _cargar().whenComplete(() => _enCurso = null);
  }

  static Future<void> _cargar() async {
    try {
      final tamanos = await _repo.getTamanos();
      if (tamanos.isEmpty) return;
      _tamanoMasBarato = tamanos
          .map((t) => t.precioBase)
          .reduce((a, b) => a < b ? a : b);
    } catch (e) {
      // Sin conexión no se rompe nada: las tarjetas se quedan sin precio
      // hasta la próxima carga. Es preferible a mostrar un número inventado.
      debugPrint('[PreciosService] no se pudieron cargar los tamaños: $e');
    }
  }

  /// Precio más bajo al que se puede comprar un sabor con este [recargo].
  ///
  /// Devuelve null mientras no se hayan cargado los tamaños, para que quien
  /// lo use pueda no pintar nada en vez de pintar un cero.
  static double? desde(double recargo) {
    final base = _tamanoMasBarato;
    return base == null ? null : base + recargo;
  }
}
