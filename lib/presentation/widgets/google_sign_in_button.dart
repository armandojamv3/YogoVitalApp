import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Botón "Continuar con Google".
///
/// Estaba escrito dentro de WelcomePage, así que solo existía en la pantalla
/// de bienvenida. Quien entraba por "Iniciar sesión" ya no lo veía y tenía
/// que retroceder para encontrarlo — mucha gente no lo intenta. Al extraerlo
/// aquí puede usarse en las dos pantallas sin duplicar el dibujo del logo.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool cargando;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: cargando ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          side: const BorderSide(color: Color(0xFFDADADA), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: cargando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LogoGoogle(),
                  const SizedBox(width: 10),
                  // Flexible + ellipsis: en pantallas estrechas, o con el
                  // tamaño de fuente del sistema aumentado, el texto se
                  // salía del botón y Flutter pintaba las franjas amarillas
                  // y negras de desbordamiento.
                  Flexible(
                    child: Text(
                      'Continuar con Google',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Logo "G" de Google dibujado a mano, sin depender de una imagen.
class _LogoGoogle extends StatelessWidget {
  const _LogoGoogle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _PintorLogoGoogle()),
    );
  }
}

class _PintorLogoGoogle extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final grosor = size.width * 0.18;

    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.butt;

    final circulo =
        Rect.fromCircle(center: Offset(cx, cy), radius: r - grosor / 2);

    // Azul arriba
    trazo.color = const Color(0xFF4285F4);
    canvas.drawArc(circulo, -1.5708 - 0.7854, 1.5708, false, trazo);

    // Rojo a la derecha
    trazo.color = const Color(0xFFEA4335);
    canvas.drawArc(circulo, -0.7854, 1.5708, false, trazo);

    // Amarillo abajo
    trazo.color = const Color(0xFFFBBC05);
    canvas.drawArc(circulo, 0.7854, 1.5708, false, trazo);

    // Verde a la izquierda
    trazo.color = const Color(0xFF34A853);
    canvas.drawArc(circulo, 2.3562, 1.5708, false, trazo);

    // Relleno blanco interior
    canvas.drawCircle(
      Offset(cx, cy),
      r - grosor,
      Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white,
    );

    // Barra horizontal de la G
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - grosor * 0.45, cx + r - grosor * 0.3,
          cy + grosor * 0.45),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
