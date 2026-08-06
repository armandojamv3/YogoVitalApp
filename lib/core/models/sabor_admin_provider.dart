import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/data/repositories/sabores_admin_repository.dart';

enum SaborFormState { idle, saving, success, error }

/// Provider para el módulo admin de sabores.
/// Sprint 6: usa SaboresAdminRepository (Supabase directo, no REST).
class SaborAdminProvider extends ChangeNotifier {
  final SaboresAdminRepository repository;

  List<Sabor> _sabores = [];
  bool _loadingList = false;
  String? _listError;
  SaborFormState _formState = SaborFormState.idle;
  String? _formError;
  String? _formSuccess;

  List<Sabor> get sabores => List.unmodifiable(_sabores);
  bool get loadingList => _loadingList;
  String? get listError => _listError;
  SaborFormState get formState => _formState;
  String? get formError => _formError;
  String? get formSuccess => _formSuccess;
  bool get isSaving => _formState == SaborFormState.saving;

  SaborAdminProvider({SaboresAdminRepository? repository})
      : repository = repository ?? SaboresAdminRepository();

  // ── Cargar lista ────────────────────────────────────────────────────────

  Future<void> cargarSabores() async {
    _loadingList = true;
    _listError = null;
    notifyListeners();
    try {
      _sabores = await repository.getSabores();
    } catch (e) {
      _listError = e is SaboresAdminException
          ? e.message
          : 'Error al cargar sabores.';
    } finally {
      _loadingList = false;
      notifyListeners();
    }
  }

  // ── HU_AgregarSabor_32 ──────────────────────────────────────────────────

  Future<bool> agregarSabor({
    required String nombre,
    required String descripcion,
    required double precioBase,
    String? imagenUrl,
  }) async {
    _setFormState(SaborFormState.saving);
    try {
      final nuevo = await repository.createSabor(
        nombre: nombre,
        descripcion: descripcion,
        precioBase: precioBase,
        imagenUrl: imagenUrl,
      );
      _sabores = [nuevo, ..._sabores];
      _formSuccess = "Sabor '$nombre' agregado correctamente";
      _setFormState(SaborFormState.success);
      return true;
    } catch (e) {
      _formError = e is SaboresAdminException
          ? e.message
          : 'No se pudo agregar el sabor.';
      _setFormState(SaborFormState.error);
      return false;
    }
  }

  // ── HU_EditarSabor_33 ───────────────────────────────────────────────────

  Future<bool> actualizarSabor({
    required String id,
    required String nombre,
    required String descripcion,
    required double precioBase,
    String? imagenUrl,
  }) async {
    _setFormState(SaborFormState.saving);
    try {
      final actualizado = await repository.updateSabor(
        id: id,
        nombre: nombre,
        descripcion: descripcion,
        precioBase: precioBase,
        imagenUrl: imagenUrl,
      );
      _sabores = _sabores.map((s) => s.id == id ? actualizado : s).toList();
      _formSuccess = 'Sabor actualizado correctamente';
      _setFormState(SaborFormState.success);
      return true;
    } catch (e) {
      _formError = e is SaboresAdminException
          ? e.message
          : 'No se pudo actualizar el sabor.';
      _setFormState(SaborFormState.error);
      return false;
    }
  }

  // ── HU_EliminarSabor_34 ─────────────────────────────────────────────────

  Future<bool> eliminarSabor(String id) async {
    _setFormState(SaborFormState.saving);
    try {
      final tienePedidos = await repository.tienePedidosActivos(id);
      if (tienePedidos) {
        _formError = 'No se puede eliminar: este sabor tiene pedidos activos.';
        _setFormState(SaborFormState.error);
        return false;
      }
      await repository.deleteSabor(id);
      _sabores = _sabores
          .map((s) => s.id == id ? s.copyWith(activo: false) : s)
          .toList();
      _formSuccess = 'Sabor eliminado correctamente';
      _setFormState(SaborFormState.success);
      return true;
    } catch (e) {
      _formError = e is SaboresAdminException
          ? e.message
          : 'No se pudo eliminar el sabor.';
      _setFormState(SaborFormState.error);
      return false;
    }
  }

  void resetFormState() {
    _formState = SaborFormState.idle;
    _formError = null;
    _formSuccess = null;
    notifyListeners();
  }

  void _setFormState(SaborFormState state) {
    _formState = state;
    notifyListeners();
  }
}
