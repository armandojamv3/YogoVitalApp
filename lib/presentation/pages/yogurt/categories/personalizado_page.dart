import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:yogo_vital_app/core/models/extra.dart';
import 'package:yogo_vital_app/core/models/fruta.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/core/models/tamano_model.dart';
import 'package:yogo_vital_app/core/providers/pedido_provider.dart';
import 'package:yogo_vital_app/data/repositories/personalizacion_repository.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';

/// Punto de entrada: usa el PedidoProvider de nivel app (provisto en main.dart).
/// Resetea el estado al entrar para garantizar un pedido fresco cada vez.
class PersonalizadoPage extends StatelessWidget {
  final Sabor? initialSabor;
  const PersonalizadoPage({super.key, this.initialSabor});

  @override
  Widget build(BuildContext context) {
    return _PersonalizadoContent(initialSabor: initialSabor);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contenido principal
// ─────────────────────────────────────────────────────────────────────────────
class _PersonalizadoContent extends StatefulWidget {
  final Sabor? initialSabor;
  const _PersonalizadoContent({this.initialSabor});

  @override
  State<_PersonalizadoContent> createState() => _PersonalizadoContentState();
}

class _PersonalizadoContentState extends State<_PersonalizadoContent> {
  final _repo = PersonalizacionRepository();
  final _cop = NumberFormat.currency(
      locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  // Datos cargados desde Supabase
  List<TamanoModel> _tamanos = [];
  List<Sabor> _sabores = [];
  List<Fruta> _frutas = [];
  List<Extra> _extras = [];

  bool _loading = true;
  String? _loadError;

  // UI: sabor expandido (descripción inline)
  String? _expandedSaborId;

  @override
  void initState() {
    super.initState();
    // Resetear estado anterior antes de iniciar nueva personalización
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pedido = context.read<PedidoProvider>();
      pedido.reset();
      if (widget.initialSabor != null) {
        pedido.selectSabor(widget.initialSabor!);
      }
    });
    _loadAll();
  }

  // ── Carga inicial (todas las tablas en paralelo) ──────────────────────────
  Future<void> _loadAll() async {
    debugPrint('[Personalizado] _loadAll inicio');
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _repo.getTamanos(),
        _repo.getSabores(),
        _repo.getFrutas(),
        _repo.getExtras(),
      ]);

      if (!mounted) return;
      final tamanos = results[0] as List<TamanoModel>;
      final sabores = results[1] as List<Sabor>;
      final frutas  = results[2] as List<Fruta>;
      final extras  = results[3] as List<Extra>;

      debugPrint('[Personalizado] tamanos=${tamanos.length} sabores=${sabores.length} '
          'frutas=${frutas.length} extras=${extras.length}');

      setState(() {
        _tamanos = tamanos;
        _sabores = sabores;
        _frutas  = frutas;
        _extras  = extras;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[Personalizado] ERROR cargando: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loadError = 'Error al cargar las opciones: $e\nToca para reintentar.';
        _loading = false;
      });
    }
  }

  // ── "Ver Resumen" → navegar a ResumenPedidoPage (HU_19) ──────────────────
  void _showResumen(PedidoProvider pedido) {
    // Navegar conservando la pila para que "Editar" (HU_20) pueda volver
    Navigator.pushNamed(context, '/resumen-pedido');
  }


  // ── Build principal ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    debugPrint('[Personalizado] build: loading=$_loading error=$_loadError');

    final pedido = context.watch<PedidoProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Personalizar Yogur'),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontSize: 12)),
                      Text(
                        _cop.format(pedido.total),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: ElevatedButton(
                    onPressed: pedido.canAddToCart
                        ? () => _showResumen(pedido)
                        : null,
                    child: const Text('Ver Resumen'),
                  ),
                ),
              ],
            ),
          ),
          const CustomBottomNavBar(currentIndex: 1),
        ],
      ),
      body: _buildBodyContent(pedido),
    );
  }

  Widget _buildBodyContent(PedidoProvider pedido) {
    if (_loading) {
      debugPrint('[Personalizado] mostrando loading spinner');
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      debugPrint('[Personalizado] mostrando error state');
      return _buildErrorState();
    }
    debugPrint('[Personalizado] mostrando contenido');
    return _buildScrollContent(pedido);
  }

  // ── Estado de error ───────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _loadError ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAll,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5 secciones de personalización ───────────────────────────────────────
  Widget _buildScrollContent(PedidoProvider pedido) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          // Sección 1: Tamaño
          _sectionCard(
            number: '1',
            title: 'Selecciona el Tamaño',
            subtitle: 'El precio base depende del tamaño',
            // Guard obligatorio: GridView con itemCount 0 no completa layout
            child: _tamanos.isEmpty
                ? _emptySection('No hay tamaños disponibles')
                : _buildTamanosGrid(pedido),
          ),

          const SizedBox(height: 16),

          // Sección 2: Sabor
          _sectionCard(
            number: '2',
            title: 'Elige tu Sabor Base',
            subtitle: 'Toca una opción para ver su descripción',
            child: _buildSaboresList(pedido),
          ),

          const SizedBox(height: 16),

          // Sección 3: Nivel de dulzura
          _sectionCard(
            number: '3',
            title: 'Nivel de Dulzura',
            subtitle: 'Elige qué tan dulce quieres tu yogur',
            child: _buildDulzuraSelector(pedido),
          ),

          const SizedBox(height: 16),

          // Sección 4: Frutas
          _sectionCard(
            number: '4',
            title: 'Agrega Frutas',
            subtitle: 'Máximo $kMaxFrutas frutas',
            badgeText: '${pedido.frutas.length}/$kMaxFrutas',
            child: _frutas.isEmpty
                ? _emptySection('No hay frutas disponibles')
                : _buildIngredientesList(
                    items: _frutas
                        .map((f) => _IngredienteItem(
                              id: f.id,
                              nombre: f.nombre,
                              precio: f.precioAdicional,
                              imagenUrl: f.imagenUrl,
                              isSelected: pedido.isFrutaSelectedById(f.id),
                              onToggle: () => _onToggleFruta(f, pedido),
                            ))
                        .toList(),
                  ),
          ),

          const SizedBox(height: 16),

          // Sección 5: Extras
          _sectionCard(
            number: '5',
            title: 'Agrega Extras',
            subtitle: 'Máximo $kMaxExtras extras',
            badgeText: '${pedido.extras.length}/$kMaxExtras',
            child: _extras.isEmpty
                ? _emptySection('No hay extras disponibles')
                : _buildIngredientesList(
                    items: _extras
                        .map((e) => _IngredienteItem(
                              id: e.id,
                              nombre: e.nombre,
                              precio: e.precioAdicional,
                              imagenUrl: e.imagenUrl,
                              isSelected: pedido.isExtraSelectedById(e.id),
                              onToggle: () => _onToggleExtra(e, pedido),
                            ))
                        .toList(),
                  ),
          ),

          const SizedBox(height: 20),
      ],
    ),
    );
  }

  // ── Selector de nivel de dulzura (Objetivo 3: niveles de dulzura) ────────
  Widget _buildDulzuraSelector(PedidoProvider pedido) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kNivelesDulzura.map((nivel) {
        final selected = pedido.dulzura == nivel;
        return GestureDetector(
          onTap: () => pedido.selectDulzura(nivel),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF5B9EF5) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF5B9EF5)
                    : Colors.grey[300]!,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              nivel,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── HU_14 + HU_15: toggle fruta con validación de límite ─────────────────
  void _onToggleFruta(Fruta f, PedidoProvider pedido) {
    final added = pedido.toggleFruta(f);
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Máximo $kMaxFrutas frutas permitidas'),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onToggleExtra(Extra e, PedidoProvider pedido) {
    final added = pedido.toggleExtra(e);
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Máximo $kMaxExtras extras permitidos'),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── TamanoCard (HU_10 + HU_11) ────────────────────────────────────────────
  Widget _buildTamanosGrid(PedidoProvider pedido) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.0,
      ),
      itemCount: _tamanos.length,
      itemBuilder: (_, i) {
        final t = _tamanos[i];
        final selected = pedido.tamano?.id == t.id;
        return GestureDetector(
          onTap: () => pedido.selectTamano(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF5B9EF5) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? const Color(0xFF5B9EF5)
                    : Colors.grey[300]!,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF5B9EF5)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected)
                  const Icon(Icons.check_circle,
                      size: 16, color: Colors.white),
                Text(
                  t.nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _cop.format(t.precioBase),
                  style: TextStyle(
                    fontSize: 13,
                    color: selected
                        ? Colors.white70
                        : const Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── SaborCard (HU_12 + HU_13) ─────────────────────────────────────────────
  Widget _buildSaboresList(PedidoProvider pedido) {
    return Column(
      children: _sabores.map((s) {
        final selected = pedido.sabor?.id == s.id;
        final expanded = _expandedSaborId == s.id;

        return Column(
          children: [
            GestureDetector(
              onTap: () {
                // HU_12: seleccionar + HU_13: expandir descripción
                pedido.selectSabor(s);
                setState(() =>
                    _expandedSaborId = expanded ? null : s.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE8F5E9)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF4CAF50)
                        : Colors.grey[200]!,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Miniatura del sabor
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: s.imagenUrl != null
                          ? Image.network(
                              s.imagenUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.orange[50],
                                );
                              },
                              errorBuilder: (_, __, ___) =>
                                  _saborPlaceholder(),
                            )
                          : _saborPlaceholder(),
                    ),
                    const SizedBox(width: 12),

                    // Nombre + hint
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: selected
                                  ? const Color(0xFF2E7D32)
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            expanded
                                ? 'Toca para cerrar'
                                : 'Toca para ver descripción',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Indicador de selección
                    if (selected)
                      const Icon(Icons.check_circle,
                          color: Color(0xFF4CAF50), size: 20)
                    else
                      Icon(Icons.radio_button_unchecked,
                          color: Colors.grey[400], size: 20),

                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey[400],
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),

            // HU_13: expansión inline de la descripción
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FBE7),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  border: Border.all(
                      color: const Color(0xFFC5E1A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.descripcion,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87),
                    ),
                    if (s.precioBase > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Precio base: ${_cop.format(s.precioBase)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _saborPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: Colors.orange[50],
      child: const Icon(Icons.icecream, color: Colors.orange, size: 28),
    );
  }

  // ── IngredienteToggle — frutas y extras (HU_14 + HU_16 + HU_18) ──────────
  Widget _buildIngredientesList(
      {required List<_IngredienteItem> items}) {
    return Column(
      children: items.map((item) {
        return GestureDetector(
          onTap: item.onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: item.isSelected
                  ? const Color(0xFFE8F5E9)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: item.isSelected
                    ? const Color(0xFF4CAF50)
                    : Colors.grey[200]!,
                width: item.isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Imagen o ícono
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.imagenUrl != null
                      ? Image.network(
                          item.imagenUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _ingredientePlaceholder(),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return _ingredientePlaceholder();
                          },
                        )
                      : _ingredientePlaceholder(),
                ),
                const SizedBox(width: 12),

                // Nombre
                Expanded(
                  child: Text(
                    item.nombre,
                    style: TextStyle(
                      fontWeight: item.isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: item.isSelected
                          ? const Color(0xFF2E7D32)
                          : Colors.black87,
                    ),
                  ),
                ),

                // Precio adicional
                if (item.precio > 0)
                  Text(
                    '+${_cop.format(item.precio)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: item.isSelected
                          ? const Color(0xFF2E7D32)
                          : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                const SizedBox(width: 8),

                // Toggle visual
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: item.isSelected
                        ? const Color(0xFF4CAF50)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.isSelected
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: item.isSelected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _ingredientePlaceholder() {
    return Container(
      width: 40,
      height: 40,
      color: Colors.green[50],
      child:
          const Icon(Icons.local_florist, color: Colors.green, size: 22),
    );
  }

  // ── HU_17: barra de precio en tiempo real ─────────────────────────────────
  Widget _buildPrecioBar(PedidoProvider pedido) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(color: Colors.grey.shade200, width: 1)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          // Expanded absorbe el espacio libre → el botón nunca recibe ancho infinito
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 11)),
                Text(
                  _cop.format(pedido.total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),

          // HU_10: botón deshabilitado si no hay tamaño seleccionado
          ElevatedButton.icon(
            onPressed: pedido.tamano == null
                ? null
                : () => _showResumen(pedido),
            icon: const Icon(Icons.receipt_long,
                color: Colors.white, size: 18),
            label: const Text(
              'Ver Resumen',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B9EF5),
              disabledBackgroundColor: Colors.grey[300],
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de layout ─────────────────────────────────────────────────────
  Widget _sectionCard({
    required String number,
    required String title,
    required String subtitle,
    required Widget child,
    String? badgeText,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado de sección
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Número de paso
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF5B9EF5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      number,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500])),
                    ],
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B9EF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(badgeText,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),

          // Contenido de la sección
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _emptySection(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(msg,
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DTO interno para los items de ingredientes (frutas y extras comparten UI)
// ─────────────────────────────────────────────────────────────────────────────
class _IngredienteItem {
  final String id;
  final String nombre;
  final double precio;
  final String? imagenUrl;
  final bool isSelected;
  final VoidCallback onToggle;

  const _IngredienteItem({
    required this.id,
    required this.nombre,
    required this.precio,
    this.imagenUrl,
    required this.isSelected,
    required this.onToggle,
  });
}
