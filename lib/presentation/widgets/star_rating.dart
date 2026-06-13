import 'package:flutter/material.dart';

/// Widget de 5 estrellas reutilizable.
/// - [interactive] = true → tap para seleccionar (formulario calificación)
/// - [interactive] = false → solo lectura (catálogo, resumen)
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final bool interactive;
  final ValueChanged<int>? onRatingChanged;
  final Color activeColor;
  final Color inactiveColor;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 28,
    this.interactive = false,
    this.onRatingChanged,
    this.activeColor = const Color(0xFFFFB300),
    this.inactiveColor = const Color(0xFFE0E0E0),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = starIndex <= rating.round();

        final star = Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled ? activeColor : inactiveColor,
        );

        if (!interactive) return star;

        return GestureDetector(
          onTap: () => onRatingChanged?.call(starIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: star,
          ),
        );
      }),
    );
  }
}
