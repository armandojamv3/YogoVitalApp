import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/extra.dart';
import 'package:yogo_vital_app/core/models/fruta.dart';
import 'package:yogo_vital_app/data/repositories/inventario_admin_repository.dart';

enum CatalogoFormState { idle, saving, success, error }

/// Provider para frutas y extras con Supabase Realtime.
/// Sprint 7: migrado de REST API a stream subscriptions.
class FrutaExtraAdminProvider extends ChangeNotifier {
  final InventarioAdminRepository _repo;

  StreamSubscription<List<Fruta>>? _frutasSub;
  StreamSubscription<List<Extra>>? _extrasSub;

  // ── Estado Frutas ────────────────────────────────────────────────────────
  List<Fruta> _frutas = [];
  bool _loadingFrutas = true;
  String? _frutaListError;

  List<Fruta> get frutas => _frutas;
  bool get loadingFrutas => _loadingFrutas;
  String? get frutaListError => _frutaListError;

  // ── Estado Extras ────────────────────────────────────────────────────────
  List<Extra> _extras = [];
  bool _loadingExtras = true;
  String? _extraListError;

  List<Extra> get extras => _extras;
  bool get loadingExtras => _loadingExtras;
  String? get extraListError => _extraListError;

  // ── Estado Formulario ────────────────────────────────────────────────────
  CatalogoFormState _formState = CatalogoFormState.idle;
  String? _formError;
  String? _formSuccess;

  CatalogoFormState get formState => _formState;
  String? get formError => _formError;
  String? get formSuccess => _formSuccess;
  bool get isSaving => _formState == CatalogoFormState.saving;

  FrutaExtraAdminProvider({InventarioAdminRepository? repo})
      : _repo = repo ?? InventarioAdminRepository() {
    _initStreams();
  }

  void _initStreams() {
    _frutasSub = _repo.streamFrutas().listen(
      (data) {
        _frutas = data;
        _loadingFrutas = false;
        _frutaListError = null;
        notifyListeners();
      },
      onError: (e) {
        _frutaListError = 'Error al cargar frutas: $e';
        _loadingFrutas = false;
        notifyListeners();
      },
    );

    _extrasSub = _repo.streamExtras().listen(
      (data) {
        _extras = data;
        _loadingExtras = false;
        _extraListError = null;
        notifyListeners();
      },
      onError: (e) {
        _extraListError = 'Error al cargar extras: $e';
        _loadingExtras = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _frutasSub?.cancel();
    _extrasSub?.cancel();
    super.dispose();
  }

  void resetFormState() {
    _formState = CatalogoFormState.idle;
    _formError = null;
    _formSuccess = null;
    notifyListeners();
  }

  // Mantenidas por compatibilidad con la UI (refresh manual)
  Future<void> cargarFrutas() async {}
  Future<void> cargarExtras() async {}

  // ── FRUTAS ──────────────────────────────────────────────────────────────

  Future<bool> agregarFruta({
    required String nombre,
    required double precioAdicional,
  }) async {
    _set(CatalogoFormState.saving);
    try {
      await _repo.createFruta(nombre: nombre, precioAdicional: precioAdicional);
      _formSuccess = 'Fruta agregada correctamente';
      _set(CatalogoFormState.success);
      return true;
    } on InventarioException catch (e) {
      _formError = e.message;
      _set(CatalogoFormState.error);
      return false;
    }
  }

  Future<bool> actualizarFruta({
    required String id,
    required String nombre,
    required double precioAdicional,
  }) async {
    _set(CatalogoFormState.saving);
    try {
      await _repo.updateFruta(
          id: id, nombre: nombre, precioAdicional: precioAdicional);
      _formSuccess = 'Fruta actualizada correctamente';
      _set(CatalogoFormState.success);
      return true;
    } on InventarioException catch (e) {
      _formError = e.message;
      _set(CatalogoFormState.error);
      return false;
    }
  }

  Future<void> toggleFrutaDisponibilidad(String id,
      {required bool disponible}) async {
    // Actualización optimista
    final idx = _frutas.indexWhere((f) => f.id == id);
    if (idx != -1) {
      _frutas[idx] = _frutas[idx].copyWith(disponible: disponible);
      notifyListeners();
    }
    try {
      await _repo.toggleDisponibilidadFruta(id, disponible: disponible);
    } catch (_) {
      // Revertir si falla
      if (idx != -1) {
        _frutas[idx] = _frutas[idx].copyWith(disponible: !disponible);
        notifyListeners();
      }
    }
  }

  Future<void> eliminarFruta(String id) async {
    try {
      await _repo.deleteFruta(id);
      _formSuccess = 'Fruta eliminada correctamente';
      notifyListeners();
    } on InventarioException catch (e) {
      _formError = e.message;
      _set(CatalogoFormState.error);
    }
  }

  // ── EXTRAS ──────────────────────────────────────────────────────────────

  Future<bool> agregarExtra({
    required String nombre,
    required double precioAdicional,
  }) async {
    _set(CatalogoFormState.saving);
    try {
      await _repo.createExtra(nombre: nombre, precioAdicional: precioAdicional);
      _formSuccess = 'Extra agregado correctamente';
      _set(CatalogoFormState.success);
      return true;
    } on InventarioException catch (e) {
      _formError = e.message;
      _set(CatalogoFormState.error);
      return false;
    }
  }

  Future<bool> actualizarExtra({
    required String id,
    required String nombre,
    required double precioAdicional,
  }) async {
    _set(CatalogoFormState.saving);
    try {
      await _repo.updateExtra(
          id: id, nombre: nombre, precioAdicional: precioAdicional);
      _formSuccess = 'Extra actualizado correctamente';
      _set(CatalogoFormState.success);
      return true;
    } on InventarioException catch (e) {
      _formError = e.message;
      _set(CatalogoFormState.error);
      return false;
    }
  }

  Future<void> toggleExtraDisponibilidad(String id,
      {required bool disponible}) async {
    final idx = _extras.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _extras[idx] = _extras[idx].copyWith(disponible: disponible);
      notifyListeners();
    }
    try {
      await _repo.toggleDisponibilidadExtra(id, disponible: disponible);
    } catch (_) {
      if (idx != -1) {
        _extras[idx] = _extras[idx].copyWith(disponible: !disponible);
        notifyListeners();
      }
    }
  }

  Future<void> eliminarExtra(String id) async {
    try {
      await _repo.deleteExtra(id);
      _formSuccess = 'Extra eliminado correctamente';
      notifyListeners();
    } on InventarioException catch (e) {
      _formError = e.message;
      _set(CatalogoFormState.error);
    }
  }

  void _set(CatalogoFormState state) {
    _formState = state;
    notifyListeners();
  }
}
