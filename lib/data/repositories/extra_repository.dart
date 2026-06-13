import 'package:yogo_vital_app/core/models/extra.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';

/// Excepción de dominio para operaciones sobre extras.
class ExtraException implements Exception {
  final String message;
  final int? statusCode;
  const ExtraException(this.message, {this.statusCode});

  @override
  String toString() => 'ExtraException($statusCode): $message';
}

/// Repositorio CRUD para la tabla `extras`.
///
/// Endpoints REST:
///   GET    `/extras`       → List[Extra]
///   POST   `/extras`       → Extra (admin)
///   PUT    `/extras/:id`   → Extra (admin)
///   PATCH  `/extras/:id`   → Extra (admin) – toggle disponibilidad / soft-delete
class ExtraRepository {
  final ApiClient apiClient;

  ExtraRepository({required this.apiClient});

  // ─────────────────────────────────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Extra>> obtenerExtras({bool soloDisponibles = false}) async {
    try {
      final path = soloDisponibles ? '/extras?disponible=true' : '/extras';
      final data = await apiClient.getDynamic(path);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Extra.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      throw _mapError(e, 'No se pudo cargar la lista de extras.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE
  // ─────────────────────────────────────────────────────────────────────────

  Future<Extra> agregarExtra({
    required String nombre,
    required double precioAdicional,
  }) async {
    try {
      final data = await apiClient.post('/extras', {
        'nombre': nombre.trim(),
        'precio_adicional': precioAdicional,
        'disponible': true,
      });
      return Extra.fromJson(data);
    } catch (e) {
      throw _mapError(e, 'No se pudo agregar el extra.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPDATE
  // ─────────────────────────────────────────────────────────────────────────

  Future<Extra> actualizarExtra({
    required String id,
    required String nombre,
    required double precioAdicional,
  }) async {
    try {
      final data = await apiClient.put('/extras/$id', {
        'nombre': nombre.trim(),
        'precio_adicional': precioAdicional,
      });
      return Extra.fromJson(data);
    } catch (e) {
      throw _mapError(e, 'No se pudo actualizar el extra.');
    }
  }

  /// Toggle rápido de disponibilidad (HU_35)
  Future<void> toggleDisponibilidad(String id, {required bool disponible}) async {
    try {
      await apiClient.patch('/extras/$id', {'disponible': disponible});
    } catch (e) {
      throw _mapError(e, 'No se pudo cambiar la disponibilidad.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOFT-DELETE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> eliminarExtra(String id) async {
    try {
      await apiClient.patch('/extras/$id', {'disponible': false});
    } catch (e) {
      throw _mapError(e, 'No se pudo eliminar el extra.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper
  // ─────────────────────────────────────────────────────────────────────────

  ExtraException _mapError(Object e, String fallback) {
    if (e is ExtraException) return e;
    final msg = e.toString();
    if (msg.contains('403') || msg.contains('401')) {
      return const ExtraException(
        'No tienes permiso para realizar esta acción.',
        statusCode: 403,
      );
    }
    if (msg.contains('409') || msg.contains('conflict')) {
      return const ExtraException(
        'Ya existe un extra con ese nombre.',
        statusCode: 409,
      );
    }
    if (msg.contains('422') || msg.contains('validation')) {
      return const ExtraException(
        'Datos inválidos. Verifica los campos.',
        statusCode: 422,
      );
    }
    return ExtraException(fallback);
  }
}
