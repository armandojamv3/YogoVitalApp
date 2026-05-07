import 'package:flutter/material.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';

/// Pantalla para personalizar un yogurt (Mockup)
class PersonalizadoPage extends StatefulWidget {
  const PersonalizadoPage({super.key});

  @override
  State<PersonalizadoPage> createState() => _PersonalizadoPageState();
}

class _PersonalizadoPageState extends State<PersonalizadoPage> {
  // Estado del formulario
  String _selectedSize = 'Personal(300)';
  String _selectedBase = 'Durazno';
  String? _selectedFruit;
  bool _extrasChispas = false;
  String _sugarLevel = 'Normal';
  String _sweetener = 'Miel';

  // Opciones disponibles (puedes ajustarlas)
  final List<String> sizes = ['Personal(300)', '1 Litro', '2 Litro'];
  final List<String> bases = ['Durazno', 'Mango', 'Coco', 'Fresa'];
  final List<String> fruits = ['Durazno', 'Mango', 'Coco', 'Fresa'];
  final List<String> sugarLevels = [
    'Sin Azucar',
    'Bajo',
    'Normal',
    'Extra Dulce',
  ];
  final List<String> sweeteners = [
    'blanca',
    'morena',
    'Panela',
    'Stevia',
    'Miel',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF5B9EF5)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '< Volver',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Image.asset('assets/images/logo.png', height: 36),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Busqueda proximamente')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Imagen del producto centrada
            Container(
              height: 140,
              width: double.infinity,
              color: const Color(0xFF5B9EF5),
              child: Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/yogurt_personal_a.png',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.image,
                        size: 60,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Tarjeta con el formulario de personalización
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'Personaliza tu yogur',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tamaño
                      const Text(
                        'Tamaño',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: sizes.map((s) {
                          final selected = _selectedSize == s;
                          return ChoiceChip(
                            label: Text(s),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _selectedSize = s),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 12),

                      // Sabor Base
                      const Text(
                        'Sabor Base',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        children: bases.map((b) {
                          return GestureDetector(
                            onTap: () => setState(() => _selectedBase = b),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.orange[50],
                                  child: const Icon(
                                    Icons.local_drink,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  b,
                                  style: TextStyle(
                                    color: _selectedBase == b
                                        ? Colors.black
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 12),

                      // Fruta adicional (opcional)
                      const Text(
                        'Fruta adicional',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: fruits.map((f) {
                          return ChoiceChip(
                            label: Text(f),
                            selected: _selectedFruit == f,
                            onSelected: (_) => setState(
                              () => _selectedFruit = _selectedFruit == f
                                  ? null
                                  : f,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 12),

                      // Extras
                      const Text(
                        'Extras',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Checkbox(
                            value: _extrasChispas,
                            onChanged: (v) =>
                                setState(() => _extrasChispas = v ?? false),
                          ),
                          const SizedBox(width: 6),
                          const Text('Chispas de chocolate'),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Nivel de Azucar
                      const Text(
                        'Nivel de Azucar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: sugarLevels
                            .map(
                              (s) => ChoiceChip(
                                label: Text(s),
                                selected: _sugarLevel == s,
                                onSelected: (_) =>
                                    setState(() => _sugarLevel = s),
                              ),
                            )
                            .toList(),
                      ),

                      const SizedBox(height: 12),

                      // Tipo de Endulzante
                      const Text(
                        'Tipo de Endulzante',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: sweeteners
                            .map(
                              (sw) => ChoiceChip(
                                label: Text(sw),
                                selected: _sweetener == sw,
                                onSelected: (_) =>
                                    setState(() => _sweetener = sw),
                              ),
                            )
                            .toList(),
                      ),

                      const SizedBox(height: 16),

                      // Botones Cancelar y Crear
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              // Resetear formulario
                              setState(() {
                                _selectedSize = sizes[0];
                                _selectedBase = bases[0];
                                _selectedFruit = null;
                                _extrasChispas = false;
                                _sugarLevel = sugarLevels[2];
                                _sweetener = sweeteners.last;
                              });
                            },
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              final resumen =
                                  'Pedido creado: $_selectedSize, base $_selectedBase';
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(resumen)));
                            },
                            child: const Text('Crear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom nav (reutilizable)
            const CustomBottomNavBar(currentIndex: 1),
          ],
        ),
      ),
    );
  }
}
