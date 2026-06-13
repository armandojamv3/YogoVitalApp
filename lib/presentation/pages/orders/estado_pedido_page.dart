import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/models/calificacion.dart';
import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/core/models/estado_pedido_provider.dart';
import 'package:yogo_vital_app/data/repositories/calificacion_repository.dart';
import 'package:yogo_vital_app/data/repositories/pedido_repository.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';

/// HU_VerEstadoPedido_26 – Ver estado actual del pedido con Realtime.
///
/// Recibe [pedidoId] como argumento de ruta:
///   Navigator.pushNamed(context, '/estado-pedido', arguments: 'abc-123');
class EstadoPedidoPage extends StatelessWidget {
  final String pedidoId;
  const EstadoPedidoPage({super.key, required this.pedidoId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final apiClient = ApiClient(baseUrl: 'http://localhost:8080');
        final repo = PedidoRepository(apiClient: apiClient);
        final calRepo = CalificacionRepository(apiClient: apiClient);
        return EstadoPedidoProvider(repository: repo, calificacionRepository: calRepo)
          ..iniciarSeguimiento(pedidoId);
      },
      child: _EstadoPedidoView(pedidoId: pedidoId),
    );
  }
}

class _EstadoPedidoView extends StatefulWidget {
  final String pedidoId;
  const _EstadoPedidoView({required this.pedidoId});

  @override
  State<_EstadoPedidoView> createState() => _EstadoPedidoViewState();
}

class _EstadoPedidoViewState extends State<_EstadoPedidoView>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Para notificaciones in-app al detectar cambio de estado
  String? _ultimoEstadoNotificado;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _mostrarNotificacionCambio(BuildContext context, String nuevoEstado) {
    final estadoEnum = EstadoPedidoExtension.fromString(nuevoEstado);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: estadoEnum.color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Icon(estadoEnum.icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Tu pedido ahora está: ${estadoEnum.label}!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Consumer<EstadoPedidoProvider>(
        builder: (context, provider, _) {
          // Detectar cambio de estado para notificación in-app
          final estadoActual = provider.pedido?.estadoRaw;
          if (estadoActual != null &&
              _ultimoEstadoNotificado != null &&
              estadoActual != _ultimoEstadoNotificado) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _mostrarNotificacionCambio(context, estadoActual);
            });
          }
          if (estadoActual != null) _ultimoEstadoNotificado = estadoActual;

          return SafeArea(
            child: Column(
              children: [
                _buildHeader(context, provider),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF5B9EF5),
                    onRefresh: () => provider.recargar(widget.pedidoId),
                    child: _buildBody(context, provider),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, EstadoPedidoProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A8FE7), Color(0xFF5B9EF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Estado del Pedido',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          // Indicador Realtime pulsante
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF69F0AE),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body principal ──────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, EstadoPedidoProvider provider) {
    switch (provider.loadState) {
      case PedidoLoadState.loading:
        return _buildLoading();
      case PedidoLoadState.error:
        return _buildError(provider);
      case PedidoLoadState.loaded:
        return _buildContent(provider.pedido!);
      case PedidoLoadState.initial:
        return _buildLoading();
    }
  }

  Widget _buildLoading() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              CircularProgressIndicator(
                color: Color(0xFF5B9EF5),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Obteniendo estado del pedido…',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(EstadoPedidoProvider provider) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 64, color: Color(0xFFEF5350)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  provider.errorMessage ?? 'Ocurrió un error inesperado.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF5A5A5A)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => provider.recargar(widget.pedidoId),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9EF5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(Pedido pedido) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ─ Tarjeta ID y fecha ─
        _buildInfoCard(pedido),
        const SizedBox(height: 20),
        // ─ Estado grande con ícono ─
        _buildEstadoCard(pedido),
        const SizedBox(height: 20),
        // ─ Timeline de progreso ─
        _buildTimeline(pedido.estado),
        const SizedBox(height: 20),
        // ─ Última actualización ─
        _buildUltimaActualizacion(pedido),
        const SizedBox(height: 20),
        // ─ Calificación (solo si está Entregado) ─
        if (pedido.estado == EstadoPedido.entregado)
          _CalificacionCard(pedidoId: pedido.id),
        const SizedBox(height: 10),
        // ─ Tip Realtime ─
        _buildRealtimeBadge(),
      ],
    );
  }

  // ── Tarjeta info básica ─────────────────────────────────────────────────
  Widget _buildInfoCard(Pedido pedido) {
    final fechaFmt = DateFormat('dd/MM/yyyy – HH:mm').format(pedido.createdAt);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF5B9EF5).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: Color(0xFF5B9EF5), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido #${pedido.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Realizado: $fechaFmt',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: COP ${_formatPrecio(pedido.total)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0E8498),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Estado actual grande ────────────────────────────────────────────────
  Widget _buildEstadoCard(Pedido pedido) {
    final estado = pedido.estado;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            estado.color.withValues(alpha: 0.85),
            estado.color,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: estado.color.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(estado.icon, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estado actual',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                estado.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Timeline de progreso ────────────────────────────────────────────────
  static const _ordenEstados = [
    EstadoPedido.recibido,
    EstadoPedido.enPreparacion,
    EstadoPedido.enCamino,
    EstadoPedido.entregado,
  ];

  Widget _buildTimeline(EstadoPedido estadoActual) {
    // Si está cancelado mostramos aviso especial
    if (estadoActual == EstadoPedido.cancelado) {
      return _buildCanceladoBanner();
    }

    final idxActual = _ordenEstados.indexOf(estadoActual);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progreso del pedido',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_ordenEstados.length, (i) {
            final e = _ordenEstados[i];
            final isDone = idxActual >= i;
            final isCurrent = idxActual == i;
            final isLast = i == _ordenEstados.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: círculo + línea
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? e.color
                            : Colors.grey.shade200,
                        border: isCurrent
                            ? Border.all(color: e.color, width: 3)
                            : null,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: e.color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : e.icon,
                        size: 17,
                        color: isDone ? Colors.white : Colors.grey,
                      ),
                    ),
                    if (!isLast)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 3,
                        height: 36,
                        decoration: BoxDecoration(
                          color: idxActual > i
                              ? _ordenEstados[i + 1].color
                                  .withValues(alpha: 0.6)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isDone
                              ? const Color(0xFF1A1A2E)
                              : Colors.grey,
                        ),
                      ),
                      if (!isLast) const SizedBox(height: 26),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCanceladoBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF5350), width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_rounded, color: Color(0xFFEF5350), size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Pedido cancelado',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFFEF5350),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Este pedido fue cancelado y no será procesado.',
                  style: TextStyle(color: Color(0xFF5A5A5A), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Última actualización ────────────────────────────────────────────────
  Widget _buildUltimaActualizacion(Pedido pedido) {
    final fmt = DateFormat('dd/MM/yyyy – HH:mm:ss').format(
      pedido.updatedAt.toLocal(),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded,
              color: Color(0xFF5B9EF5), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Última actualización',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fmt,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Badge Realtime ──────────────────────────────────────────────────────
  Widget _buildRealtimeBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Actualización automática cada 10 seg',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  String _formatPrecio(double precio) {
    final fmt = NumberFormat('#,##0', 'es_CO');
    return fmt.format(precio);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Tarjeta de calificación del pedido (HU_CalificarPedido_30)
// Se muestra solo cuando pedido.estado == Entregado
// ─────────────────────────────────────────────────────────────────────────────

class _CalificacionCard extends StatefulWidget {
  final String pedidoId;
  const _CalificacionCard({required this.pedidoId});

  @override
  State<_CalificacionCard> createState() => _CalificacionCardState();
}

class _CalificacionCardState extends State<_CalificacionCard> {
  int _estrellas = 0;
  final _comentarioCtrl = TextEditingController();
  static const _kGold = Color(0xFFFFC107);
  static const _kPrimary = Color(0xFF5B9EF5);
  static const _kDanger = Color(0xFFEF5350);
  static const _kSuccess = Color(0xFF4CAF50);

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EstadoPedidoProvider>(
      builder: (ctx, prov, _) {
        // ── Ya calificado → mostrar calificación guardada (solo lectura) ──
        if (prov.yaCalificado && prov.calificacion != null) {
          return _buildCalificadaView(prov.calificacion!);
        }

        // ── Cargando calificación existente ──
        if (prov.calificacionState == CalificacionState.loading) {
          return const SizedBox(
            height: 60,
            child: Center(
              child: CircularProgressIndicator(
                  color: _kPrimary, strokeWidth: 2.5),
            ),
          );
        }

        // ── Formulario de calificación ──
        return _buildFormView(ctx, prov);
      },
    );
  }

  Widget _buildCalificadaView(Calificacion cal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kGold.withValues(alpha: 0.08),
            _kGold.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded,
                    color: _kGold, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Tu calificación',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Estrellas de solo lectura
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < cal.estrellas
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: i < cal.estrellas ? _kGold : Colors.grey.shade300,
                size: 30,
              );
            }),
          ),
          if (cal.comentario != null && cal.comentario!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '"${cal.comentario}"',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5A5A5A),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: _kSuccess, size: 16),
              const SizedBox(width: 6),
              Text(
                'Gracias por tu opinión',
                style: TextStyle(
                  fontSize: 12,
                  color: _kSuccess.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormView(BuildContext context, EstadoPedidoProvider prov) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rate_review_rounded,
                    color: _kGold, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '¿Cómo estuvo tu pedido?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // StarRating interactivo
          Center(
            child: _StarRating(
              estrellas: _estrellas,
              onChanged: (v) => setState(() => _estrellas = v),
            ),
          ),

          if (_estrellas > 0) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                _labelEstrellas(_estrellas),
                style: const TextStyle(
                  color: _kGold,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Campo comentario
          TextField(
            controller: _comentarioCtrl,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Comentario opcional (máx. 200 caracteres)…',
              hintStyle:
                  const TextStyle(fontSize: 13, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: _kGold, width: 1.5),
              ),
              counterStyle: const TextStyle(fontSize: 11),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          // Error
          if (prov.calificacionState == CalificacionState.error &&
              prov.calificacionError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kDanger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: _kDanger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(prov.calificacionError!,
                        style: const TextStyle(
                            color: _kDanger, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Botón enviar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _estrellas == 0 || prov.calificacionCargando
                  ? null
                  : () => _enviarCalificacion(context, prov),
              icon: prov.calificacionCargando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                prov.calificacionCargando
                    ? 'Guardando…'
                    : 'Enviar calificación',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _estrellas == 0 ? Colors.grey : _kGold,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    Colors.grey.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarCalificacion(
      BuildContext context, EstadoPedidoProvider prov) async {
    final ok = await prov.enviarCalificacion(
      pedidoId: widget.pedidoId,
      estrellas: _estrellas,
      comentario: _comentarioCtrl.text,
    );
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('¡Gracias por calificar tu pedido!',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: _kSuccess,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _labelEstrellas(int n) {
    switch (n) {
      case 1:
        return 'Muy malo 😞';
      case 2:
        return 'Malo 😕';
      case 3:
        return 'Regular 😐';
      case 4:
        return 'Bueno 😊';
      case 5:
        return '¡Excelente! 🌟';
      default:
        return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Selector de estrellas interactivo
// ─────────────────────────────────────────────────────────────────────────────

class _StarRating extends StatelessWidget {
  final int estrellas;
  final ValueChanged<int> onChanged;
  static const _kGold = Color(0xFFFFC107);

  const _StarRating({required this.estrellas, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < estrellas;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled ? _kGold : Colors.grey.shade300,
              size: filled ? 42 : 38,
            ),
          ),
        );
      }),
    );
  }
}
