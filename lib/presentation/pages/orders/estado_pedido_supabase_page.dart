import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/core/utils/id_format.dart';
import 'package:yogo_vital_app/data/repositories/pedido_supabase_repository.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:yogo_vital_app/presentation/widgets/estado_badge.dart';
import 'package:yogo_vital_app/presentation/widgets/estado_pedido_timeline.dart';

/// HU_26: Pantalla de seguimiento con Supabase Realtime.
/// Recibe [pedidoId] como argumento de ruta.
class EstadoPedidoSupabasePage extends StatefulWidget {
  final String pedidoId;
  const EstadoPedidoSupabasePage({super.key, required this.pedidoId});

  @override
  State<EstadoPedidoSupabasePage> createState() =>
      _EstadoPedidoSupabasePageState();
}

class _EstadoPedidoSupabasePageState
    extends State<EstadoPedidoSupabasePage> {
  final _repo = PedidoSupabaseRepository();
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  // null cuando no llega pedidoId (p. ej. al recargar la página en web, donde
  // los settings.arguments de la ruta no se conservan). Evita consultar con id
  // vacío y permite mostrar un error claro en su lugar.
  Stream<Pedido?>? _stream;
  Pedido? _last; // último estado para detectar cambios

  @override
  void initState() {
    super.initState();
    // HU_26: stream Realtime — se actualiza sin recargar.
    // Solo se abre el stream si tenemos un pedidoId válido.
    if (widget.pedidoId.isNotEmpty) {
      _stream = _repo.streamPedido(widget.pedidoId);
    }
  }

  // HU_23: confirmar cancelación
  Future<void> _cancelar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text(
            '¿Estás seguro de que deseas cancelar este pedido?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('Sí, cancelar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await _repo.cancelarPedido(widget.pedidoId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu pedido fue cancelado correctamente'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F4),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF5B9EF5), Color(0xFF4A8FE7)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    // Esta pantalla se llega vía "Ver mi pedido", que limpia
                    // la pila de navegación (pushNamedAndRemoveUntil). Un
                    // Navigator.pop() genérico aquí queda en un estado
                    // ambiguo (pantalla en blanco). Navegamos explícitamente
                    // a Historial, que es a donde el usuario espera volver.
                    onTap: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil('/history', (r) => false),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Estado del pedido',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Indicador LIVE de Realtime
                  _LiveIndicator(),
                ],
              ),
            ),

            // ID del pedido
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              color: const Color(0xFF5B9EF5).withValues(alpha: 0.1),
              child: Text(
                'Pedido: ${shortId(widget.pedidoId)}',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF5B9EF5),
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),

            Expanded(
              child: _stream == null
                  ? _buildError(
                      'No se pudo identificar el pedido.\n'
                      'Vuelve a "Mis pedidos" e inténtalo de nuevo.')
                  : StreamBuilder<Pedido?>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildError(snapshot.error.toString());
                  }

                  final pedido = snapshot.data;
                  if (pedido == null) {
                    return const Center(
                        child: Text('Pedido no encontrado'));
                  }

                  // Notificar cambios de estado en la misma sesión
                  if (_last != null &&
                      _last!.estadoRaw != pedido.estadoRaw) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '📦 Tu pedido cambió a: ${pedido.estado.label}',
                          ),
                          backgroundColor: pedido.estado.color,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    });
                  }
                  _last = pedido;

                  return _buildContent(pedido);
                },
              ),
            ),

            const CustomBottomNavBar(currentIndex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Pedido pedido) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tarjeta estado principal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: pedido.estado.color.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Ícono animado
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: pedido.estado.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    pedido.estado.icon,
                    size: 44,
                    color: pedido.estado.color,
                  ),
                ),
                const SizedBox(height: 16),

                // Badge de estado
                EstadoBadge(estado: pedido.estadoRaw, fontSize: 15),

                const SizedBox(height: 12),

                // Última actualización
                Text(
                  'Última actualización: ${_fmt.format(pedido.updatedAt.toLocal())}',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 12),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 4),
                Text(
                  'Pedido realizado: ${_fmt.format(pedido.createdAt.toLocal())}',
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Línea de tiempo del pedido
          EstadoPedidoTimeline(estadoActual: pedido.estado),

          const SizedBox(height: 16),

          // Total
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total del pedido',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  NumberFormat.currency(
                          locale: 'es_CO',
                          symbol: '\$',
                          decimalDigits: 0)
                      .format(pedido.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      fontSize: 16),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // HU_23: botón cancelar (solo si estado == Recibido)
          if (pedido.estado == EstadoPedido.recibido)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cancelar,
                icon: const Icon(Icons.cancel_outlined,
                    color: Colors.red),
                label: const Text('Cancelar pedido',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(msg, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/history', (r) => false),
                icon: const Icon(Icons.history),
                label: const Text('Ir a Mis Pedidos'),
              ),
            ],
          ),
        ),
      );
}

/// Punto parpadeante indicando conexión Realtime activa
class _LiveIndicator extends StatefulWidget {
  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50), shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            const Text('LIVE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
