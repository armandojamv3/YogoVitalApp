import 'package:flutter/material.dart';

/// Posibles estados de un pedido en Yogo Vital
enum EstadoPedido {
  recibido,
  enPreparacion,
  enCamino,
  entregado,
  cancelado,
  desconocido,
}

/// Extensión para parsear/formatear [EstadoPedido]
extension EstadoPedidoExtension on EstadoPedido {
  static EstadoPedido fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'recibido':
        return EstadoPedido.recibido;
      case 'en preparación':
      case 'en preparacion':
        return EstadoPedido.enPreparacion;
      case 'en camino':
        return EstadoPedido.enCamino;
      case 'entregado':
        return EstadoPedido.entregado;
      case 'cancelado':
        return EstadoPedido.cancelado;
      default:
        return EstadoPedido.desconocido;
    }
  }

  String get label {
    switch (this) {
      case EstadoPedido.recibido:
        return 'Recibido';
      case EstadoPedido.enPreparacion:
        return 'En preparación';
      case EstadoPedido.enCamino:
        return 'En camino';
      case EstadoPedido.entregado:
        return 'Entregado';
      case EstadoPedido.cancelado:
        return 'Cancelado';
      case EstadoPedido.desconocido:
        return 'Desconocido';
    }
  }

  Color get color {
    switch (this) {
      case EstadoPedido.recibido:
        return const Color(0xFF5B9EF5); // azul
      case EstadoPedido.enPreparacion:
        return const Color(0xFFFF9800); // naranja
      case EstadoPedido.enCamino:
        return const Color(0xFF9C27B0); // morado
      case EstadoPedido.entregado:
        return const Color(0xFF4CAF50); // verde
      case EstadoPedido.cancelado:
        return const Color(0xFFF44336); // rojo
      case EstadoPedido.desconocido:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case EstadoPedido.recibido:
        return Icons.inbox_rounded;
      case EstadoPedido.enPreparacion:
        return Icons.blender_rounded;
      case EstadoPedido.enCamino:
        return Icons.local_shipping_rounded;
      case EstadoPedido.entregado:
        return Icons.check_circle_rounded;
      case EstadoPedido.cancelado:
        return Icons.cancel_rounded;
      case EstadoPedido.desconocido:
        return Icons.help_outline_rounded;
    }
  }
}

/// Modelo principal de Pedido — mapeado a la tabla `pedidos` de Supabase/PostgreSQL.
class Pedido {
  final String id;
  final String clienteId;
  final String? direccion;
  final double total;
  final String estadoRaw; // valor crudo de la BD
  final DateTime createdAt;
  final DateTime updatedAt;

  const Pedido({
    required this.id,
    required this.clienteId,
    this.direccion,
    required this.total,
    required this.estadoRaw,
    required this.createdAt,
    required this.updatedAt,
  });

  EstadoPedido get estado => EstadoPedidoExtension.fromString(estadoRaw);

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      id: json['id']?.toString() ?? '',
      clienteId: json['cliente_id']?.toString() ?? '',
      direccion: json['direccion'] as String?,
      total: _parseDouble(json['total']),
      estadoRaw: json['estado'] as String? ?? 'Desconocido',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cliente_id': clienteId,
    'direccion': direccion,
    'total': total,
    'estado': estadoRaw,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  /// Crea una copia con campos actualizados (útil para Realtime)
  Pedido copyWith({
    String? estadoRaw,
    DateTime? updatedAt,
  }) {
    return Pedido(
      id: id,
      clienteId: clienteId,
      direccion: direccion,
      total: total,
      estadoRaw: estadoRaw ?? this.estadoRaw,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}

/// Modelo de ítem de pedido — tabla `pedido_items`
class PedidoItem {
  final String id;
  final String pedidoId;
  final String producto;
  final String tamano;
  final String sabor;
  final List<String> frutas;
  final List<String> extras;
  final double precio;

  const PedidoItem({
    required this.id,
    required this.pedidoId,
    required this.producto,
    required this.tamano,
    required this.sabor,
    required this.frutas,
    required this.extras,
    required this.precio,
  });

  factory PedidoItem.fromJson(Map<String, dynamic> json) {
    return PedidoItem(
      id: json['id']?.toString() ?? '',
      pedidoId: json['pedido_id']?.toString() ?? '',
      producto: json['producto'] as String? ?? '',
      tamano: json['tamano'] as String? ?? '',
      sabor: json['sabor'] as String? ?? '',
      frutas: _parseList(json['frutas']),
      extras: _parseList(json['extras']),
      precio: Pedido._parseDouble(json['precio']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pedido_id': pedidoId,
    'producto': producto,
    'tamano': tamano,
    'sabor': sabor,
    'frutas': frutas,
    'extras': extras,
    'precio': precio,
  };

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }
}
