import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/pedido.dart';

/// HU_26: chip visual que muestra el estado del pedido con color e ícono.
class EstadoBadge extends StatelessWidget {
  final String estado;
  final double fontSize;

  const EstadoBadge({
    super.key,
    required this.estado,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final ep = EstadoPedidoExtension.fromString(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ep.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ep.color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ep.icon, size: fontSize + 3, color: ep.color),
          const SizedBox(width: 6),
          Text(
            ep.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: ep.color,
            ),
          ),
        ],
      ),
    );
  }
}
