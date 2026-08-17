import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagen de un producto, con caché en disco.
///
/// ── Por qué existe ────────────────────────────────────────────────────
/// La app usaba `Image.network` en trece sitios. Ese widget **no guarda
/// nada**: cada vez que Flutter reconstruye el widget vuelve a pedir la
/// imagen a Supabase Storage. Desplazar una lista, cambiar de pestaña o
/// volver atrás disparaba una descarga nueva de cada foto.
///
/// `cached_network_image` ya estaba en el pubspec desde hace tiempo, pero
/// solo lo usaba un repositorio. Con él la imagen se descarga una vez, se
/// guarda en disco y las siguientes veces se lee de ahí.
///
/// [alto] y [ancho] no son solo para el diseño: se pasan a
/// `memCacheHeight`/`memCacheWidth` para que la imagen se decodifique al
/// tamaño en que se va a ver. Una foto de 2000 px mostrada en una tarjeta
/// de 150 ocupa en memoria unas 175 veces más de lo necesario, y eso es
/// buena parte de los tirones al desplazar.
class ImagenProducto extends StatelessWidget {
  final String? url;
  final double? alto;
  final double? ancho;
  final BoxFit ajuste;

  /// Icono de respaldo cuando no hay imagen o falla la descarga.
  final IconData iconoVacio;
  final double tamanoIcono;

  /// Colores del respaldo. Se dejan configurables porque en las pantallas de
  /// administración la imagen ya va dentro de una tarjeta con degradado y un
  /// fondo naranja encima desentona.
  final Color? colorFondoRespaldo;
  final Color? colorIcono;

  const ImagenProducto({
    super.key,
    required this.url,
    this.alto,
    this.ancho,
    this.ajuste = BoxFit.cover,
    this.iconoVacio = Icons.icecream,
    this.tamanoIcono = 40,
    this.colorFondoRespaldo,
    this.colorIcono,
  });

  bool get _esRemota => (url ?? '').startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (!_esRemota) return _respaldo();

    // La densidad de pantalla importa: en un teléfono con dpr 3, una caja
    // de 100 px lógicos necesita 300 px reales para verse nítida.
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return CachedNetworkImage(
      imageUrl: url!,
      height: alto,
      width: ancho,
      fit: ajuste,
      memCacheHeight: _enPixeles(alto, dpr),
      memCacheWidth: _enPixeles(ancho, dpr),
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _respaldo(),
    );
  }

  /// Convierte una medida lógica a píxeles reales para el caché.
  ///
  /// Devuelve null si la medida no sirve para dimensionar: `double.infinity`
  /// es un valor legítimo para pedirle a un widget que ocupe todo el ancho
  /// disponible, pero `infinity.round()` revienta con "Infinity or NaN toInt".
  /// En ese caso simplemente no limitamos el caché en ese eje.
  int? _enPixeles(double? medida, double dpr) {
    if (medida == null || !medida.isFinite || medida <= 0) return null;
    return (medida * dpr).round();
  }

  /// Mientras descarga: un bloque gris suave, sin ruedas giratorias. En una
  /// rejilla, media docena de indicadores girando a la vez distrae más de
  /// lo que informa.
  Widget _placeholder() => Container(
        height: alto,
        width: ancho,
        color: Colors.grey[200],
      );

  Widget _respaldo() => Container(
        height: alto,
        width: ancho,
        alignment: Alignment.center,
        color: colorFondoRespaldo ?? Colors.orange[100],
        child: Icon(iconoVacio,
            size: tamanoIcono, color: colorIcono ?? Colors.orange),
      );
}
