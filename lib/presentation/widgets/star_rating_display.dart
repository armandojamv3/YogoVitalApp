import 'package:flutter/material.dart';
import 'package:yogo_vital_app/presentation/widgets/star_rating.dart';

/// Widget compacto de promedio de calificación para catálogo y Home.
///
/// Muestra ★★★★☆ 4.2 (12). Si el producto **no tiene ninguna calificación**
/// no dibuja nada: mostrar estrellas vacías o un 5.0 de relleno le atribuye
/// al producto una nota que nadie le ha dado.
class StarRatingDisplay extends StatelessWidget {
  /// null = todavía nadie lo ha calificado.
  final double? promedio;

  /// null = no mostrar conteo; 0 = "Sin calificaciones"
  final int? total;
  final double starSize;
  final TextStyle? textStyle;

  const StarRatingDisplay({
    super.key,
    required this.promedio,
    this.total,
    this.starSize = 14,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final nota = promedio;
    if (nota == null || total == 0) return const SizedBox.shrink();

    final label = total != null
        ? '${nota.toStringAsFixed(1)} ($total)'
        : nota.toStringAsFixed(1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StarRating(
          rating: nota,
          size: starSize,
          interactive: false,
          activeColor: const Color(0xFFFFB300),
          inactiveColor: const Color(0xFFE0E0E0),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: textStyle ??
              TextStyle(
                fontSize: starSize * 0.85,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
