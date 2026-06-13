import 'dart:async';
import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/calificacion.dart';
import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/data/repositories/calificacion_repository.dart';
import 'package:yogo_vital_app/data/repositories/pedido_repository.dart';

/// Estado de carga de la pantalla
enum PedidoLoadState { initial, loading, loaded, error }

/// Estado de la operación de calificación
enum CalificacionState { idle, loading, saving, saved, error }

/// Provider que gestiona el estado en tiempo real de un pedido específico
/// y el flujo de calificación del cliente (HU_CalificarPedido_30).
class EstadoPedidoProvider extends ChangeNotifier {
  final PedidoRepository repository;
  final CalificacionRepository? calificacionRepository;

  Pedido? _pedido;
  PedidoLoadState _loadState = PedidoLoadState.initial;
  String? _errorMessage;
  StreamSubscription<Pedido>? _realtimeSubscription;

  // ── Calificación ─────────────────────────────────────────────────────────
  Calificacion? _calificacion;
  CalificacionState _calificacionState = CalificacionState.idle;
  String? _calificacionError;

  Pedido? get pedido => _pedido;
  PedidoLoadState get loadState => _loadState;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loadState == PedidoLoadState.loading;

  Calificacion? get calificacion => _calificacion;
  CalificacionState get calificacionState => _calificacionState;
  String? get calificacionError => _calificacionError;
  bool get yaCalificado => _calificacion != null;
  bool get calificacionCargando =>
      _calificacionState == CalificacionState.loading ||
      _calificacionState == CalificacionState.saving;

  EstadoPedidoProvider({
    required this.repository,
    this.calificacionRepository,
  });

  /// Inicia la carga y suscripción Realtime para [pedidoId].
  void iniciarSeguimiento(String pedidoId) {
    _loadState = PedidoLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    _realtimeSubscription?.cancel();

    _realtimeSubscription = repository
        .streamEstadoPedido(pedidoId)
        .listen(
          (pedido) {
            if (_pedido?.estadoRaw != pedido.estadoRaw ||
                _pedido?.updatedAt != pedido.updatedAt) {
              _pedido = pedido;
              _loadState = PedidoLoadState.loaded;
              notifyListeners();
            } else if (_loadState != PedidoLoadState.loaded) {
              _pedido = pedido;
              _loadState = PedidoLoadState.loaded;
              notifyListeners();
            }
            // Si el pedido está entregado, cargar calificación existente
            if (pedido.estado == EstadoPedido.entregado &&
                _calificacionState == CalificacionState.idle) {
              _cargarCalificacion(pedidoId);
            }
          },
          onError: (Object e) {
            _errorMessage = e is PedidoException
                ? e.message
                : 'Error al obtener el estado del pedido.';
            _loadState = PedidoLoadState.error;
            notifyListeners();
          },
        );
  }

  /// Fuerza una recarga inmediata (pull-to-refresh)
  Future<void> recargar(String pedidoId) async {
    _loadState = PedidoLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _pedido = await repository.obtenerEstadoPedido(pedidoId);
      _loadState = PedidoLoadState.loaded;
      if (_pedido?.estado == EstadoPedido.entregado) {
        _cargarCalificacion(pedidoId);
      }
    } catch (e) {
      _errorMessage = e is PedidoException
          ? e.message
          : 'No se pudo actualizar el estado.';
      _loadState = PedidoLoadState.error;
    } finally {
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Calificación – HU_CalificarPedido_30
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _cargarCalificacion(String pedidoId) async {
    if (calificacionRepository == null) return;
    _calificacionState = CalificacionState.loading;
    notifyListeners();
    try {
      _calificacion = await calificacionRepository!
          .obtenerCalificacionPorPedido(pedidoId);
      _calificacionState = _calificacion != null
          ? CalificacionState.saved
          : CalificacionState.idle;
    } catch (_) {
      _calificacionState = CalificacionState.idle;
    } finally {
      notifyListeners();
    }
  }

  /// Envía la calificación del cliente para el pedido actual.
  Future<bool> enviarCalificacion({
    required String pedidoId,
    required int estrellas,
    String? comentario,
  }) async {
    if (calificacionRepository == null) return false;
    _calificacionState = CalificacionState.saving;
    _calificacionError = null;
    notifyListeners();
    try {
      _calificacion = await calificacionRepository!.enviarCalificacion(
        pedidoId: pedidoId,
        estrellas: estrellas,
        comentario: comentario,
      );
      _calificacionState = CalificacionState.saved;
      notifyListeners();
      return true;
    } catch (e) {
      _calificacionError = e is CalificacionException
          ? e.message
          : 'No se pudo guardar la calificación.';
      _calificacionState = CalificacionState.error;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
