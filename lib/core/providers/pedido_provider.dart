import 'package:flutter/foundation.dart';
import 'package:yogo_vital_app/core/models/extra.dart';
import 'package:yogo_vital_app/core/models/fruta.dart';
import 'package:yogo_vital_app/core/models/pedido_local_model.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/core/models/tamano_model.dart';

/// HU_15: máximo 2 frutas por pedido personalizado.
const int kMaxFrutas = 2;

/// Máximo 3 extras por pedido personalizado.
const int kMaxExtras = 3;

/// Objetivo 3: niveles de dulzura disponibles para personalizar el pedido.
const List<String> kNivelesDulzura = ['Bajo', 'Normal', 'Alto'];

/// Provider del pedido en construcción. Se provee a nivel de
/// PersonalizadoPage (no global), para que se resetee al salir.
class PedidoProvider extends ChangeNotifier {
  PedidoLocalModel _state = const PedidoLocalModel();

  // ── Getters ──────────────────────────────────────────────────────────────
  PedidoLocalModel get state => _state;
  TamanoModel? get tamano => _state.tamano;
  Sabor? get sabor => _state.sabor;
  String get dulzura => _state.dulzura;
  List<Fruta> get frutas => _state.frutas;
  List<Extra> get extras => _state.extras;

  /// HU_17: precio total actualizado en CADA cambio
  double get total => _state.total;

  bool get frutasLimitReached => _state.frutas.length >= kMaxFrutas;
  bool get canAddToCart => _state.tamano != null && _state.sabor != null;

  // ── HU_10 + HU_11: seleccionar tamaño ───────────────────────────────────
  void selectTamano(TamanoModel t) {
    _state = _state.copyWith(tamano: t);
    notifyListeners();
  }

  // ── HU_12: seleccionar sabor ─────────────────────────────────────────────
  void selectSabor(Sabor s) {
    _state = _state.copyWith(sabor: s);
    notifyListeners();
  }

  // ── Objetivo 3: seleccionar nivel de dulzura ────────────────────────────
  void selectDulzura(String nivel) {
    if (!kNivelesDulzura.contains(nivel)) return;
    _state = _state.copyWith(dulzura: nivel);
    notifyListeners();
  }

  // ── HU_14 + HU_15: toggle fruta (máx 2) ─────────────────────────────────
  /// Devuelve `false` si el límite se alcanzó y no se pudo agregar.
  bool toggleFruta(Fruta fruta) {
    final current = List<Fruta>.from(_state.frutas);
    final idx = current.indexWhere((f) => f.id == fruta.id);
    if (idx >= 0) {
      // HU_18: deseleccionar / eliminar
      current.removeAt(idx);
    } else {
      // HU_15: validar límite antes de agregar
      if (current.length >= kMaxFrutas) return false;
      current.add(fruta);
    }
    _state = _state.copyWith(frutas: current);
    notifyListeners();
    return true;
  }

  // ── HU_16 + HU_18: toggle extra (máx kMaxExtras) ───────────────────────
  /// Devuelve `false` si el límite se alcanzó y no se pudo agregar.
  bool toggleExtra(Extra extra) {
    final current = List<Extra>.from(_state.extras);
    final idx = current.indexWhere((e) => e.id == extra.id);
    if (idx >= 0) {
      current.removeAt(idx);
    } else {
      if (current.length >= kMaxExtras) return false;
      current.add(extra);
    }
    _state = _state.copyWith(extras: current);
    notifyListeners();
    return true;
  }

  bool isFrutaSelectedById(String id) =>
      _state.frutas.any((f) => f.id == id);

  bool isExtraSelectedById(String id) =>
      _state.extras.any((e) => e.id == id);

  void reset() {
    _state = const PedidoLocalModel();
    notifyListeners();
  }
}
