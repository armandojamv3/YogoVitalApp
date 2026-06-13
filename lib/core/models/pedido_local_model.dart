import 'package:yogo_vital_app/core/models/extra.dart';
import 'package:yogo_vital_app/core/models/fruta.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/core/models/tamano_model.dart';

/// Estado inmutable del yogur en construcción (antes de pasar al carrito).
class PedidoLocalModel {
  final TamanoModel? tamano;
  final Sabor? sabor;
  final List<Fruta> frutas;
  final List<Extra> extras;

  const PedidoLocalModel({
    this.tamano,
    this.sabor,
    this.frutas = const [],
    this.extras = const [],
  });

  /// HU_17: precio total calculado en tiempo real (100 % local, sin red)
  double get total {
    final base = tamano?.precioBase ?? 0;
    final frutasTotal =
        frutas.fold(0.0, (sum, f) => sum + f.precioAdicional);
    final extrasTotal =
        extras.fold(0.0, (sum, e) => sum + e.precioAdicional);
    return base + frutasTotal + extrasTotal;
  }

  PedidoLocalModel copyWith({
    TamanoModel? tamano,
    Sabor? sabor,
    List<Fruta>? frutas,
    List<Extra>? extras,
  }) =>
      PedidoLocalModel(
        tamano: tamano ?? this.tamano,
        sabor: sabor ?? this.sabor,
        frutas: frutas ?? this.frutas,
        extras: extras ?? this.extras,
      );
}
