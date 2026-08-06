import 'package:flutter/material.dart';

// NOTE: We avoid importing page widgets here to prevent circular imports.
// Navigation is done via named routes. Ensure `main.dart` registers the
// routes: '/home', '/yogurt', '/cart', '/history', '/account'.

// Definimos el color primario de tu aplicación
const Color primaryBlue = Color(0xFF4A8FE7);

class CustomBottomNavBar extends StatelessWidget {
  // El índice actual indica qué pestaña está activa
  final int currentIndex;

  // Función que se llama cuando se presiona un ítem (para manejar la navegación)
  // Si es null, el widget realizará una navegación por defecto.
  final void Function(int)? onItemTapped;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onItemTapped,
  });

  // Estructura de cada ítem de la barra de navegación
  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home, label: 'Home'), // Index 0
    _NavItem(icon: Icons.local_drink, label: 'Yogures'), // Index 1
    _NavItem(icon: Icons.shopping_cart, label: 'Carrito'), // Index 2
    _NavItem(icon: Icons.history, label: 'Historial'), // Index 3
    _NavItem(icon: Icons.person, label: 'Cuenta'), // Index 4
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
        color: Colors.white,
      ),
      // 60 px dejaban el icono y la etiqueta pegados al borde inferior: la
      // barra queda justo encima del indicador de gestos del teléfono y se
      // veía apretada. Un poco de aire arriba y abajo lo resuelve sin
      // robarle altura real al contenido de la pantalla.
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final isSelected = index == currentIndex;

          return _buildNavItem(
            context,
            index,
            item.icon,
            item.label,
            isSelected,
          );
        }),
      ),
    );
  }

  // Widget auxiliar para construir un ítem individual de la barra
  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
    bool isSelected,
  ) {
    final color = isSelected ? primaryBlue : Colors.grey;
    final fontWeight = isSelected ? FontWeight.bold : FontWeight.normal;

    return GestureDetector(
      onTap: () {
        if (onItemTapped != null) {
          onItemTapped!(index);
        } else {
          _defaultNavigate(context, index);
        }
      },
      // Sin esto solo el icono y el texto responden al toque, no el hueco
      // entre ellos ni los márgenes.
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color), // El icono cambia de color
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: fontWeight,
            ), // El texto también
          ),
        ],
      ),
    );
  }

  // Todas las pestañas limpian la pila de navegación al abrirse: cada tab
  // es la raíz de su propio flujo. Así el botón "atrás" de cada pantalla
  // solo aparece (y solo funciona) cuando de verdad se entró desde otra
  // pantalla (p. ej. detalle de yogur, estado de pedido, opciones de
  // perfil) y no cuando se llega vía la barra inferior.
  void _defaultNavigate(BuildContext context, int index) {
    const routes = ['/home', '/yogurt', '/cart', '/history', '/account'];
    if (index < 0 || index >= routes.length) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(routes[index], (route) => false);
  }
}

// Clase auxiliar para la estructura de un ítem
class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
