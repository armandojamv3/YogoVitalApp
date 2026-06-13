import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/pedido.dart';

/// Línea de tiempo visual de los estados de un pedido.
///
/// Muestra los pasos Recibido → En preparación → En camino → Entregado,
/// marcando como completados los anteriores y el actual. Si el pedido está
/// cancelado, muestra un aviso en lugar de la línea de tiempo.
///
/// Widget reutilizable: la pantalla de seguimiento en tiempo real
/// ([EstadoPedidoSupabasePage]) y el detalle del historial
/// ([HistorialDetalleScreen]) lo comparten para no duplicar código.
class EstadoPedidoTimeline extends StatelessWidget {
  /// Estado actual del pedido.
  final EstadoPedido estadoActual;

  /// Color de fondo del contenedor (por defecto blanco).
  final Color backgroundColor;

  const EstadoPedidoTimeline({
    super.key,
    required this.estadoActual,
    this.backgroundColor = Colors.white,
  });

  static const _steps = [
    EstadoPedido.recibido,
    EstadoPedido.enPreparacion,
    EstadoPedido.enCamino,
    EstadoPedido.entregado,
  ];

  @override
  Widget build(BuildContext context) {
    if (estadoActual == EstadoPedido.cancelado) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Pedido cancelado',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final currentIdx = _steps.indexOf(estadoActual);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(_steps.length, (i) {
          final step = _steps[i];
          final done = i <= currentIdx;
          final isCurrent = i == currentIdx;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: done ? step.color : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      done ? Icons.check : step.icon,
                      size: 14,
                      color: done ? Colors.white : Colors.grey,
                    ),
                  ),
                  if (i < _steps.length - 1)
                    Container(
                      width: 2,
                      height: 28,
                      color: done
                          ? step.color.withValues(alpha: 0.4)
                          : Colors.grey[200],
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    step.label,
                    style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: done ? step.color : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
