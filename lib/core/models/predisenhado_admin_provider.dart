import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/predisenhado_model.dart';
import 'package:yogo_vital_app/data/repositories/predisenhados_admin_repository.dart';

enum PredisenhadoFormState { idle, saving, success, error }

/// Provider para el módulo admin de prediseñados (mismo patrón que
/// SaborAdminProvider).
class PredisenhadoAdminProvider extends ChangeNotifier {
  final PredisenhadosAdminRepository repository;

  List<PredisenhadoModel> _predisenhados = [];
  bool _loadingList = false;
  String? _listError;
  PredisenhadoFormState _formState = PredisenhadoFormState.idle;
  String? _formError;
  String? _formSuccess;

  List<PredisenhadoModel> get predisenhados => List.unmodifiable(_predisenhados);
  bool get loadingList => _loadingList;
  String? get listError => _listError;
  PredisenhadoFormState get formState => _formState;
  String? get formError => _formError;
  String? get formSuccess => _formSuccess;
  bool get isSaving => _formState == PredisenhadoFormState.saving;

  PredisenhadoAdminProvider({PredisenhadosAdminRepository? repository})
      : repository = repository ?? PredisenhadosAdminRepository();

  // ── Cargar lista ────────────────────────────────────────────────────────

  Future<void> cargarPredisenhados() async {
    _loadingList = true;
    _listError = null;
    notifyListeners();
    try {
      _predisenhados = await repository.getPredisenhados();
    } catch (e) {
      _listError = e is PredisenhadosAdminException
          ? e.message
          : 'Error al cargar prediseñados.';
    } finally {
      _loadingList = false;
      notifyListeners();
    }
  }

  // ── Agregar ─────────────────────────────────────────────────────────────

  Future<bool> agregarPredisenhado({
    required String nombre,
    required String descripcion,
    required List<String> ingredientes,
    required double precioTotal,
    String? imagenUrl,
    bool esPopular = false,
    bool esNuevo = false,
  }) async {
    _setFormState(PredisenhadoFormState.saving);
    try {
      final nuevo = await repository.createPredisenhado(
        nombre: nombre,
        descripcion: descripcion,
        ingredientes: ingredientes,
        precioTotal: precioTotal,
        imagenUrl: imagenUrl,
        esPopular: esPopular,
        esNuevo: esNuevo,
      );
      _predisenhados = [nuevo, ..._predisenhados];
      _formSuccess = "Prediseñado '$nombre' agregado correctamente";
      _setFormState(PredisenhadoFormState.success);
      return true;
    } catch (e) {
      _formError = e is PredisenhadosAdminException
          ? e.message
          : 'No se pudo agregar el prediseñado.';
      _setFormState(PredisenhadoFormState.error);
      return false;
    }
  }

  // ── Editar ──────────────────────────────────────────────────────────────

  Future<bool> actualizarPredisenhado({
    required String id,
    required String nombre,
    required String descripcion,
    required List<String> ingredientes,
    required double precioTotal,
    String? imagenUrl,
    bool esPopular = false,
    bool esNuevo = false,
  }) async {
    _setFormState(PredisenhadoFormState.saving);
    try {
      final actualizado = await repository.updatePredisenhado(
        id: id,
        nombre: nombre,
        descripcion: descripcion,
        ingredientes: ingredientes,
        precioTotal: precioTotal,
        imagenUrl: imagenUrl,
        esPopular: esPopular,
        esNuevo: esNuevo,
      );
      _predisenhados =
          _predisenhados.map((p) => p.id == id ? actualizado : p).toList();
      _formSuccess = 'Prediseñado actualizado correctamente';
      _setFormState(PredisenhadoFormState.success);
      return true;
    } catch (e) {
      _formError = e is PredisenhadosAdminException
          ? e.message
          : 'No se pudo actualizar el prediseñado.';
      _setFormState(PredisenhadoFormState.error);
      return false;
    }
  }

  // ── Eliminar (soft-delete) ────────────────────────────────────────────

  Future<bool> eliminarPredisenhado(String id) async {
    _setFormState(PredisenhadoFormState.saving);
    try {
      await repository.deletePredisenhado(id);
      _predisenhados = _predisenhados.where((p) => p.id != id).toList();
      _formSuccess = 'Prediseñado eliminado correctamente';
      _setFormState(PredisenhadoFormState.success);
      return true;
    } catch (e) {
      _formError = e is PredisenhadosAdminException
          ? e.message
          : 'No se pudo eliminar el prediseñado.';
      _setFormState(PredisenhadoFormState.error);
      return false;
    }
  }

  void resetFormState() {
    _formState = PredisenhadoFormState.idle;
    _formError = null;
    _formSuccess = null;
    notifyListeners();
  }

  void _setFormState(PredisenhadoFormState state) {
    _formState = state;
    notifyListeners();
  }
}
