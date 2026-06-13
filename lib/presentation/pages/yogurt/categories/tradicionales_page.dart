import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/core/models/tamano_yogur.dart';

class TradicionalesPage extends StatelessWidget {
  const TradicionalesPage({super.key});

  // Mock data in the requested order with descriptions and asset paths
  List<Map<String, String>> _items() => [
    {
      'title': 'Yogurt Mora',
      'image': 'assets/images/MoraTradi.png',
      'description': 'Yogurt de mora con textura cremosa y un toque ácido.',
    },
    {
      'title': 'Yogurt Fresa',
      'image': 'assets/images/FresaTradi.png',
      'description':
          'Clásico sabor a fresa, balance perfecto entre dulzor y frescura.',
    },
    {
      'title': 'Yogurt Mango',
      'image': 'assets/images/MangoTradi.png',
      'description': 'Yogurt de mango con aroma tropical y trozos de fruta.',
    },
    {
      'title': 'Yogurt Durazno',
      'image': 'assets/images/DuraznoTradi.png',
      'description': 'Suave yogurt de durazno, ideal para desayunos y postres.',
    },
    {
      'title': 'Yogurt Melocotón',
      'image': 'assets/images/MelocotonTradi.png',
      'description': 'Melocotón natural mezclado con yogurt cremoso.',
    },
    {
      'title': 'Yogurt Piña',
      'image': 'assets/images/PinaTradi.png',
      'description': 'Refrescante yogurt de piña con un toque tropical.',
    },
    {
      'title': 'Yogurt Coco',
      'image': 'assets/images/Coco.png',
      'description': 'Cremoso yogurt con sabor a coco, perfecto con toppings.',
    },
    {
      'title': 'Yogurt Chontaduro',
      'image': 'assets/images/Chontaduro.png',
      'description': 'Sabor exótico de la región, textura única.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final tamanoFuture = _fetchTamanos();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header con degradado premium
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4A8FE7), Color(0xFF5B9EF5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Sabores Tradicionales',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Espacio simétrico
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Grid Premium de Sabores
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final it = items[index];
                    return GestureDetector(
                      onTap: () async {
                        final cart = Provider.of<CartModel>(
                          context,
                          listen: false,
                        );
                        final navigator = Navigator.of(context);
                        
                        // Abre el modal de selección múltiple
                        final res = await _showProductDialog(
                          context,
                          it,
                          tamanoFuture,
                        );
                        
                        if (res != null && res.isNotEmpty) {
                          for (final sel in res) {
                            final tamano = sel['tamano'] as TamanoYogur;
                            final qty = sel['qty'] as int;
                            cart.addItem(
                              CartItem(
                                id: 'trad_${it['title']}_${tamano.nombre}',
                                title: it['title'] ?? '',
                                price: tamano.precio.toInt(),
                                image: it['image'] ?? '',
                                size: tamano.nombre,
                                qty: qty,
                                tipo: 'tradicional',
                              ),
                            );
                          }
                          navigator.pushNamed('/cart');
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Etiqueta verde premium superior
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Text(
                                it['title'] ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),

                            // Imagen del Producto
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    it['image']!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => const Center(
                                      child: Icon(
                                        Icons.image_not_supported_rounded,
                                        size: 48,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Detalle sutil inferior
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_shopping_cart_rounded, 
                                      color: Color(0xFF4CAF50), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Elegir tamaños',
                                    style: TextStyle(
                                      color: Color(0xFF4CAF50),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const CustomBottomNavBar(currentIndex: 1),
          ],
        ),
      ),
    );
  }

  /// Obtiene tamaños desde Supabase (tabla `tamanos`, campo precio_base).
  Future<List<TamanoYogur>> _fetchTamanos() async {
    final data = await Supabase.instance.client
        .from('tamanos')
        .select()
        .order('precio_base', ascending: true);
    return (data as List).map((e) {
      final m = e as Map<String, dynamic>;
      return TamanoYogur(
        id: m['id']?.toString() ?? '',
        nombre: m['nombre']?.toString() ?? '',
        precio: (m['precio_base'] is num)
            ? (m['precio_base'] as num).toDouble()
            : double.tryParse(m['precio_base'].toString()) ?? 0,
      );
    }).toList();
  }

  Future<List<Map<String, dynamic>>?> _showProductDialog(
    BuildContext context,
    Map<String, String> item,
    Future<List<TamanoYogur>> tamanosFuture,
  ) {
    return showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final fmt = NumberFormat('#,##0', 'es_CO');
        final Map<String, int> selectedTamanos = {};

        return FutureBuilder<List<TamanoYogur>>(
          future: tamanosFuture,
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 300,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                height: 250,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudieron cargar los tamaños.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            }

            final listTamanos = snapshot.data!;

            return StatefulBuilder(
              builder: (ctx, setState) {
                // Calcular total actual
                double total = 0;
                selectedTamanos.forEach((nombre, qty) {
                  final t = listTamanos.firstWhere((element) => element.nombre == nombre);
                  total += t.precio * qty;
                });

                return Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Encabezado
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                item['image']!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.image,
                                  size: 48,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['description'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Selecciona uno o varios tamaños *',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Lista de Tamaños con Selección Múltiple y cantidad
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: listTamanos.length,
                            itemBuilder: (context, idx) {
                              final tamano = listTamanos[idx];
                              final isSelected = selectedTamanos.containsKey(tamano.nombre);
                              final qty = selectedTamanos[tamano.nombre] ?? 1;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      selectedTamanos.remove(tamano.nombre);
                                    } else {
                                      selectedTamanos[tamano.nombre] = 1;
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? const Color(0xFF4CAF50).withValues(alpha: 0.08) 
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected 
                                          ? const Color(0xFF4CAF50) 
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Checkmark circular
                                      Icon(
                                        isSelected 
                                            ? Icons.check_circle_rounded 
                                            : Icons.radio_button_off_rounded,
                                        color: isSelected 
                                            ? const Color(0xFF4CAF50) 
                                            : Colors.grey.shade400,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 14),

                                      // Nombre y precio
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tamano.nombre,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected 
                                                    ? const Color(0xFF4CAF50) 
                                                    : const Color(0xFF1A1A2E),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'COP ${fmt.format(tamano.precio)}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Selectores de cantidad (solo si está seleccionado)
                                      if (isSelected)
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  if (qty > 1) {
                                                    selectedTamanos[tamano.nombre] = qty - 1;
                                                  }
                                                });
                                              },
                                              icon: const Icon(Icons.remove_circle_outline_rounded,
                                                  color: Color(0xFF4CAF50), size: 22),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '$qty',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1A1A2E),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  selectedTamanos[tamano.nombre] = qty + 1;
                                                });
                                              },
                                              icon: const Icon(Icons.add_circle_outline_rounded,
                                                  color: Color(0xFF4CAF50), size: 22),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Barra total e interacción de Agregar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total estimado',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'COP ${fmt.format(total)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: selectedTamanos.isEmpty
                                    ? null
                                    : () {
                                        // Mapear los seleccionados para retornarlos
                                        final List<Map<String, dynamic>> res = [];
                                        selectedTamanos.forEach((nombre, qty) {
                                          final t = listTamanos.firstWhere(
                                            (element) => element.nombre == nombre,
                                          );
                                          res.add({'tamano': t, 'qty': qty});
                                        });
                                        Navigator.pop(context, res);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4CAF50),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Agregar al carrito',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
