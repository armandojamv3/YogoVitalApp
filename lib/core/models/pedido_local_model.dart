import 'package:yogo_vital_app/core/models/extra.dart';
import 'package:yogo_vital_app/core/models/fruta.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/core/models/tamano_model.dart';

/// Estado inmutable del yogur en construcción (antes de pasar al carrito).
class PedidoLocalModel {
  final TamanoModel? tamano;
  final Sabor? sabor;
  final String dulzura;
  final List<Fruta> frutas;
  final List<Extra> extras;

  const PedidoLocalModel({
    this.tamano,
    this.sabor,
    this.dulzura = 'Normal',
    this.frutas = const [],
    this.extras = const [],
  });

  /// HU_17: precio total calculado en tiempo real (100 % local, sin red)
  double get total {
    final base = tamano?.precioBase ?? 0;
    // Recargo del sabor (migración 0051). Tiene que estar aquí porque es
    // lo que suma la base de datos al confirmar: si no, el total que ve el
    // cliente mientras arma su yogur no coincide con lo que se le cobra.
    final recargoSabor = sabor?.recargo ?? 0;
    final frutasTotal =
        frutas.fold(0.0, (sum, f) => sum + f.precioAdicional);
    final extrasTotal =
        extras.fold(0.0, (sum, e) => sum + e.precioAdicional);
    return base + recargoSabor + frutasTotal + extrasTotal;
  }

  PedidoLocalModel copyWith({
    TamanoModel? tamano,
    Sabor? sabor,
    String? dulzura,
    List<Fruta>? frutas,
    List<Extra>? extras,
  }) =>
      PedidoLocalModel(
        tamano: tamano ?? this.tamano,
        sabor: sabor ?? this.sabor,
        dulzura: dulzura ?? this.dulzura,
        frutas: frutas ?? this.frutas,
        extras: extras ?? this.extras,
      );
}
