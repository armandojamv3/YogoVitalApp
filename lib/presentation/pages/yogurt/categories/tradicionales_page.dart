import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';

class TradicionalesPage extends StatelessWidget {
  const TradicionalesPage({super.key});

  // Mock data in the requested order with descriptions
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

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F4),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF5B9EF5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Image.asset('assets/images/logo.png', height: 36),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 24,
                    childAspectRatio: 0.7,
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
                        final res = await _showProductDialog(context, it);
                        if (res != null) {
                          final priceMap = {
                            'Personal (300ml)': 8000,
                            '1 Litro': 20000,
                            '1.5 Litro': 30000,
                            '2 Litros': 40000,
                          };
                          final price = priceMap[res['size']] ?? 20000;
                          cart.addItem(
                            CartItem(
                              id: 'trad_${it['title']}_${res['size']}',
                              title: it['title'] ?? '',
                              price: price,
                              image: it['image'] ?? '',
                              size: res['size'] ?? 'Personal (300ml)',
                              qty: res['qty'] ?? 1,
                            ),
                          );
                          navigator.pushNamed('/cart');
                        }
                      },
                      child: Column(
                        children: [
                          // green pill label
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              it['title'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // white square with image
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.asset(
                                    it['image']!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => const Center(
                                      child: Icon(
                                        Icons.image,
                                        size: 48,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Future<Map<String, dynamic>?> _showProductDialog(
    BuildContext context,
    Map<String, String> item,
  ) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String selectedSize = 'Personal (300ml)';
        int qty = 1;
        final sizes = ['Personal (300ml)', '1 Litro', '1.5 Litro', '2 Litros'];

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(12),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        item['image']!,
                        height: 140,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.image,
                          size: 64,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['description'] ?? '',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tamaño',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sizes.map((s) {
                        final selected = s == selectedSize;
                        return ChoiceChip(
                          label: Text(
                            s,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                            ),
                          ),
                          selected: selected,
                          selectedColor: const Color(0xFF4CAF50),
                          onSelected: (v) => setState(() => selectedSize = s),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            if (qty > 1) qty--;
                          }),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$qty',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => qty++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop({'size': selectedSize, 'qty': qty});
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
