import 'package:flutter/material.dart';
import 'package:yogo_vital_app/presentation/widgets/star_rating.dart';

/// Widget compacto de promedio de calificación para catálogo y Home.
/// Muestra: ★★★★☆ 4.2 (12)  |  "Sin calificaciones" si total == 0
class StarRatingDisplay extends StatelessWidget {
  final double promedio;

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
    if (total != null && total == 0) {
      return Text(
        'Sin calificaciones',
        style: textStyle ??
            const TextStyle(color: Colors.grey, fontSize: 11),
      );
    }

    final label = total != null
        ? '${promedio.toStringAsFixed(1)} ($total)'
        : promedio.toStringAsFixed(1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        StarRating(
          rating: promedio,
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
