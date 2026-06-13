import 'package:yogo_vital_app/core/models/tamano_yogur.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';

/// Excepción de dominio para operaciones sobre tamaños de yogur.
class TamanoYogurException implements Exception {
  final String message;
  final int? statusCode;
  const TamanoYogurException(this.message, {this.statusCode});

  @override
  String toString() => 'TamanoYogurException($statusCode): $message';
}

/// Repositorio para obtener tamaños de yogur tradicional y sus precios desde el backend.
class TamanoYogurRepository {
  final ApiClient apiClient;

  TamanoYogurRepository({required this.apiClient});

  /// Obtiene todos los tamaños ordenados por precio.
  Future<List<TamanoYogur>> obtenerTamanos() async {
    try {
      final data = await apiClient.getDynamic('/tamanos-yogur');
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(TamanoYogur.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      throw TamanoYogurException('No se pudieron cargar los tamaños de yogur.');
    }
  }
}
