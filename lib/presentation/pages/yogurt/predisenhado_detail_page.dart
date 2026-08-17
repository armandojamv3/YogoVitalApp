import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/core/models/predisenhado_model.dart';
import 'package:yogo_vital_app/core/models/tamano_model.dart';
import 'package:yogo_vital_app/data/repositories/calificacion_supabase_repository.dart';
import 'package:yogo_vital_app/data/repositories/personalizacion_repository.dart';
import 'package:yogo_vital_app/presentation/pages/cart/cart_checkout_page.dart';
import 'package:yogo_vital_app/presentation/widgets/star_rating_display.dart';
import 'package:yogo_vital_app/presentation/widgets/imagen_producto.dart';

/// Detalle de un prediseñado — equivalente a ProductDetailPage, que solo
/// servía para los sabores típicos.
///
/// Hasta ahora la tarjeta de prediseñado no era pulsable: lo único
/// interactivo era el botón "Seleccionar". Quien quisiera leer la
/// descripción completa, ver los ingredientes o las opiniones de otros
/// clientes no tenía dónde hacerlo.
class PredisenhadoDetailPage extends StatefulWidget {
  final PredisenhadoModel predisenhado;

  const PredisenhadoDetailPage({super.key, required this.predisenhado});

  @override
  State<PredisenhadoDetailPage> createState() =>
      _PredisenhadoDetailPageState();
}

class _PredisenhadoDetailPageState extends State<PredisenhadoDetailPage> {
  final _calificaciones = CalificacionSupabaseRepository();
  final _catalogo = PersonalizacionRepository();
  final _cop =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  ResenasPredisenhado _resenas = const ResenasPredisenhado.vacio();
  bool _cargandoResenas = true;

  /// Tamaños del catálogo (`tamanos_yogur`), los mismos que usan los
  /// típicos y el personalizador.
  List<TamanoModel> _tamanos = [];
  TamanoModel? _tamano;
  bool _cargandoTamanos = true;

  int _cantidad = 1;

  PredisenhadoModel get _p => widget.predisenhado;

  /// Precio unitario: la receta más el tamaño elegido. Misma fórmula que
  /// aplica la RPC crear_pedido, para que lo que se ve sea lo que se cobra.
  double get _precioUnitario => _p.precioTotal + (_tamano?.precioBase ?? 0);

  bool get _puedePedir => _tamano != null;

  /// Precio más barato posible: la receta con el tamaño más económico.
  ///
  /// `precioTotal` a secas no sirve para mostrar: es el precio de la receta
  /// sin tamaño, y como el tamaño es obligatorio, ese número no se le puede
  /// cobrar a nadie. Mostrarlo hacía que la cabecera dijera 12.000 mientras
  /// el botón cobraba 17.000.
  double? get _precioDesde {
    if (_tamanos.isEmpty) return null;
    final masBarato = _tamanos
        .map((t) => t.precioBase)
        .reduce((a, b) => a < b ? a : b);
    return _p.precioTotal + masBarato;
  }

  @override
  void initState() {
    super.initState();
    _cargarResenas();
    _cargarTamanos();
  }

  Future<void> _cargarResenas() async {
    final resenas =
        await _calificaciones.getResenasPorPredisenhado(_p.id);
    if (!mounted) return;
    setState(() {
      _resenas = resenas;
      _cargandoResenas = false;
    });
  }

  Future<void> _cargarTamanos() async {
    try {
      final tamanos = await _catalogo.getTamanos();
      if (!mounted) return;
      setState(() {
        _tamanos = tamanos;
        // Se preselecciona el primero (el más económico), igual que en los
        // yogures típicos: quien no quiera cambiar nada puede pedir directo.
        _tamano = tamanos.isNotEmpty ? tamanos.first : null;
        _cargandoTamanos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoTamanos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F4),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImagen(),
                    const SizedBox(height: 16),
                    _buildResumen(),
                    if (_p.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildDescripcion(),
                    ],
                    if (_p.ingredientes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildIngredientes(),
                    ],
                    const SizedBox(height: 16),
                    _buildTamanos(),
                    const SizedBox(height: 16),
                    _buildResenas(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildBarraAccion(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF5B9EF5),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Detalle del yogur',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Imagen con badges ─────────────────────────────────────────────────────
  Widget _buildImagen() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: ImagenProducto(
              url: _p.imagenUrl,
              alto: 220,
              ancho: double.infinity,
              tamanoIcono: 80,
            ),
          ),
        ),
        if (_p.mostrarComoNuevo || _p.esPopular)
          Positioned(
            top: 12,
            left: 12,
            child: _badge(
              _p.mostrarComoNuevo ? 'Nuevo' : 'Popular',
              _p.mostrarComoNuevo
                  ? const Color(0xFF2196F3)
                  : const Color(0xFFFF9800),
            ),
          ),
      ],
    );
  }

  Widget _badge(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          texto,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  // ── Nombre, precio y promedio ─────────────────────────────────────────────
  Widget _buildResumen() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _p.nombre,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          // Antes de elegir tamaño se muestra "Desde <el más barato>"; una
          // vez elegido, el precio exacto de esa opción. Nunca el precio de
          // la receta sola, que no es cobrable.
          if (_cargandoTamanos)
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (_tamano == null && _precioDesde != null) ...[
                  Text(
                    'Desde',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _cop.format(
                      _tamano != null ? _precioUnitario : (_precioDesde ?? 0)),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                if (_tamano != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _tamano!.nombre,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 10),
          if (_cargandoResenas)
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            StarRatingDisplay(
              promedio: _resenas.promedio,
              total: _resenas.total,
              starSize: 18,
            ),
        ],
      ),
    );
  }

  // ── Descripción ───────────────────────────────────────────────────────────
  Widget _buildDescripcion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Descripción',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            _p.descripcion,
            style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Ingredientes ──────────────────────────────────────────────────────────
  Widget _buildIngredientes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingredientes (${_p.ingredientes.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _p.ingredientes
                .map(
                  (i) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Text(
                      i,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── Tamaño (obligatorio) ──────────────────────────────────────────────────
  /// Los tamaños salen de `tamanos_yogur`, el mismo catálogo de los típicos
  /// y del personalizador. El precio final es la receta más el tamaño, así
  /// que sin elegir uno no se puede pedir.
  Widget _buildTamanos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tamaño',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(width: 6),
              Text(
                '*',
                style: TextStyle(
                  color: Colors.red[400],
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (_tamano == null && !_cargandoTamanos)
                Text(
                  'Elige uno',
                  style: TextStyle(fontSize: 12, color: Colors.red[400]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_cargandoTamanos)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_tamanos.isEmpty)
            Text(
              'No se pudieron cargar los tamaños. Revisa tu conexión.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            )
          else
            // Wrap y no Column: las tarjetas se acomodan de lado a lado y
            // saltan de línea solas cuando no caben. Ocupa mucho menos alto
            // que una fila por tamaño, así que el cliente ve las cuatro
            // opciones de un vistazo sin desplazarse.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tamanos.map(_buildTamanoOpcion).toList(),
            ),
        ],
      ),
    );
  }

  /// Tarjeta de un tamaño: nombre arriba, precio debajo.
  ///
  /// Mismo diseño que en los yogures típicos. Se quitó el círculo de radio:
  /// con el relleno de color y el borde grueso ya se ve cuál está elegido, y
  /// el icono solo robaba ancho a la tarjeta.
  Widget _buildTamanoOpcion(TamanoModel t) {
    final elegido = _tamano?.id == t.id;
    return GestureDetector(
      onTap: () => setState(() => _tamano = t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: elegido ? const Color(0xFF4CAF50) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: elegido ? const Color(0xFF4CAF50) : Colors.grey[300]!,
            width: elegido ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.nombre,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: elegido ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              // Se muestra el precio final con ese tamaño, no el recargo
              // suelto: es el número que va a pagar.
              _cop.format(_p.precioTotal + t.precioBase),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: elegido ? Colors.white70 : const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reseñas ───────────────────────────────────────────────────────────────
  Widget _buildResenas() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Opiniones de clientes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (_cargandoResenas)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_resenas.sinCalificaciones)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Sin calificaciones aún. ¡Sé el primero en opinar!',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._resenas.resenas.map(_buildResenaCard),
        ],
      ),
    );
  }

  Widget _buildResenaCard(Map<String, dynamic> resena) {
    final estrellas = (resena['estrellas'] as num?)?.toInt() ?? 0;
    final comentario = resena['comentario'] as String?;
    final fecha = (resena['created_at'] as String? ?? '').split('T').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Cliente verificado',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < estrellas ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
          if (comentario != null && comentario.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comentario,
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
          ],
          if (fecha.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              fecha,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Barra inferior: cantidad + agregar ────────────────────────────────────
  Widget _buildBarraAccion() {
    return Container(
      // Más aire abajo que arriba: la barra se apoya en el indicador de
      // gestos del teléfono y con 10 px quedaba apretada contra el borde.
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSelectorCantidad(),
          const SizedBox(width: 8),
          // Agregar al carrito: secundario, contorneado.
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: _puedePedir ? _agregarAlCarrito : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4CAF50),
                side: BorderSide(
                    color: _puedePedir
                        ? const Color(0xFF4CAF50)
                        : Colors.grey[300]!,
                    width: 1.4),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Icon(Icons.add_shopping_cart, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          // Pedir ahora: acción principal. Deshabilitada mientras no haya
          // tamaño, porque sin él no se puede calcular el precio ni crear
          // el pedido (lo rechaza la RPC).
          Expanded(
            child: SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: _puedePedir ? _pedirAhora : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  disabledBackgroundColor: Colors.grey[300],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _puedePedir ? 'Pedir ahora' : 'Elige un tamaño',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _puedePedir ? Colors.white : Colors.grey[600],
                      ),
                    ),
                    if (_puedePedir) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          _cop.format(_precioUnitario * _cantidad),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Selector compacto. Se evita IconButton a propósito: su área táctil por
  /// defecto es de 48 px y hacía la barra desproporcionada.
  Widget _buildSelectorCantidad() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pasoCantidad(
            icono: Icons.remove,
            activo: _cantidad > 1,
            onTap: () => setState(() => _cantidad--),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$_cantidad',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          _pasoCantidad(
            icono: Icons.add,
            activo: true,
            onTap: () => setState(() => _cantidad++),
          ),
        ],
      ),
    );
  }

  Widget _pasoCantidad({
    required IconData icono,
    required bool activo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: activo ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 32,
        height: 40,
        child: Icon(
          icono,
          size: 16,
          color: activo ? const Color(0xFF37474F) : Colors.grey[400],
        ),
      ),
    );
  }

  /// Ítem de carrito equivalente a este prediseñado.
  ///
  /// El prefijo 'pred_' es lo que usa CartCheckoutPage para distinguir un
  /// prediseñado de un sabor suelto y mandar el parámetro correcto a la RPC
  /// crear_pedido. Tiene que coincidir con YogurtPage.
  CartItem _comoCartItem() => CartItem(
        id: 'pred_${_p.id}',
        title: _p.nombre,
        // Precio unitario con el tamaño ya incluido, igual que lo calcula
        // la RPC. Es solo para mostrar: el cobro real lo decide el servidor.
        price: _precioUnitario.round(),
        image: _p.imagenUrl ?? '',
        size: _tamano?.nombre ?? '',
        tamanoId: _tamano?.id ?? '',
        qty: _cantidad,
      );

  /// Compra directa: va al checkout con este ítem sin pasar por el carrito.
  /// Si el usuario ya tenía cosas en el carrito, se quedan donde estaban.
  void _pedirAhora() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartCheckoutPage(itemsDirectos: [_comoCartItem()]),
      ),
    );
  }

  void _agregarAlCarrito() {
    final cart = context.read<CartModel>();
    cart.addItem(_comoCartItem());

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('${_p.nombre} agregado al carrito'),
        backgroundColor: const Color(0xFF4CAF50),
        action: SnackBarAction(
          label: 'Ver carrito',
          textColor: Colors.white,
          onPressed: () => Navigator.pushNamed(context, '/cart'),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 3), controller.close);
  }

  BoxDecoration _card() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );
}
