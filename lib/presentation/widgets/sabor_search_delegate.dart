import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/data/repositories/catalogo_repository.dart';
import 'package:yogo_vital_app/presentation/widgets/imagen_producto.dart';

/// Buscador de sabores reutilizable (Home, Yogures) vía Icons.search.
/// Usa la búsqueda nativa de Flutter (showSearch) sobre `sabores.nombre`.
class SaborSearchDelegate extends SearchDelegate<void> {
  final _repo = CatalogoRepository();
  Timer? _debounce;

  SaborSearchDelegate()
      : super(
          searchFieldLabel: 'Buscar sabor de yogur...',
        );

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Escribe el nombre de un sabor, por ejemplo "Mango"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // Pequeño debounce para no disparar una consulta por cada tecla.
    return FutureBuilder<List<Sabor>>(
      future: _debouncedSearch(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudo buscar. Verifica tu conexión.'),
          );
        }
        final resultados = snapshot.data ?? [];
        if (resultados.isEmpty) {
          return Center(
            child: Text('No encontramos sabores con "$query"',
                style: const TextStyle(color: Colors.grey)),
          );
        }
        return ListView.separated(
          itemCount: resultados.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final s = resultados[i];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ImagenProducto(
                  url: s.imagenUrl,
                  ancho: 44,
                  alto: 44,
                  tamanoIcono: 22,
                ),
              ),
              title: Text(s.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                s.descripcion,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '\$${s.precioBase.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green),
              ),
              onTap: () {
                close(context, null);
                Navigator.pushNamed(context, '/detail', arguments: {
                  'saborId': s.id,
                  'title': s.nombre,
                  'description': s.descripcion,
                  'image': s.imagenUrl ?? '',
                  'precio': s.precioBase,
                  'rating': s.calificacionPromedio,
                });
              },
            );
          },
        );
      },
    );
  }

  Future<List<Sabor>> _debouncedSearch(String q) {
    final completer = Completer<List<Sabor>>();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        completer.complete(await _repo.buscarSabores(q));
      } catch (e) {
        completer.completeError(e);
      }
    });
    return completer.future;
  }
}
