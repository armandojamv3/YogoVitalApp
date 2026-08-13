import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/core/models/pedido_historial.dart';
import 'package:yogo_vital_app/data/repositories/historial_repository.dart';
import 'package:yogo_vital_app/presentation/pages/history/historial_detalle_screen.dart';
import 'package:yogo_vital_app/presentation/widgets/custom_bottom_nav_bar.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _repo = HistorialRepository();
  final _scroll = ScrollController();

  final List<PedidoHistorial> _pedidos = [];
  int _pagina = 0;

  bool _cargandoInicial = true;
  bool _cargandoMas = false;

  /// La última página vino llena, así que puede haber más detrás.
  bool _hayMas = true;

  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
    _cargarPrimeraPagina();
  }

  @override
  void dispose() {
    _scroll.removeListener(_alDesplazar);
    _scroll.dispose();
    super.dispose();
  }

  /// Pide la siguiente página cuando faltan ~300 px para el final, para que
  /// los pedidos ya estén ahí cuando el usuario llegue abajo.
  void _alDesplazar() {
    if (!_scroll.hasClients) return;
    final falta = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (falta < 300) _cargarMas();
  }

  Future<void> _cargarPrimeraPagina() async {
    setState(() {
      _cargandoInicial = true;
      _error = null;
    });
    try {
      final pagina = await _repo.getPedidos(pagina: 0);
      if (!mounted) return;
      setState(() {
        _pedidos
          ..clear()
          ..addAll(pagina);
        _pagina = 0;
        _hayMas = pagina.length == HistorialRepository.pedidosPorPagina;
        _cargandoInicial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargandoInicial = false;
      });
    }
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas || !_hayMas || _cargandoInicial) return;
    setState(() => _cargandoMas = true);
    try {
      final siguiente = await _repo.getPedidos(pagina: _pagina + 1);
      if (!mounted) return;
      setState(() {
        _pedidos.addAll(siguiente);
        _pagina++;
        _hayMas = siguiente.length == HistorialRepository.pedidosPorPagina;
        _cargandoMas = false;
      });
    } catch (_) {
      // Un fallo al traer más no debe borrar lo que ya se está viendo. Se
      // corta la carga incremental y el usuario puede reintentar tirando
      // hacia abajo para refrescar.
      if (!mounted) return;
      setState(() {
        _cargandoMas = false;
        _hayMas = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildLista()),
            const CustomBottomNavBar(currentIndex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_cargandoInicial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) return _buildError(_error!);
    if (_pedidos.isEmpty) return _buildEmpty();

    // Una fila extra al final: el indicador de "cargando más" mientras
    // quede historial por traer.
    final total = _pedidos.length + (_hayMas ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _cargarPrimeraPagina,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i >= _pedidos.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final pedido = _pedidos[i];
          return _PedidoCard(
            pedido: pedido,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistorialDetalleScreen(pedidoId: pedido.id),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(color: Color(0xFF5B9EF5)),
      child: Row(
        children: [
          // Solo si se llegó empujando esta pantalla desde otra (p. ej.
          // desde "Mis Pedidos" en Cuenta o desde Estado del pedido).
          // Si se abrió desde la barra inferior no hay nada a lo cual
          // volver, así que no se muestra.
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 48),
          const Text(
            'Mis Pedidos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 90, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              'Aún no tienes pedidos.\n¡Haz tu primer yogur personalizado!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B9EF5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.local_drink),
              label: const Text('Ir al catálogo'),
              onPressed: () => Navigator.pushReplacementNamed(context, '/yogurt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _cargarPrimeraPagina,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PedidoCard extends StatelessWidget {
  final PedidoHistorial pedido;
  final VoidCallback onTap;

  const _PedidoCard({required this.pedido, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final estado = pedido.estado;
    final fmt = NumberFormat('#,###', 'es_CO');
    final fecha = DateFormat('dd/MM/yyyy · HH:mm').format(pedido.createdAt.toLocal());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: estado.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(estado.icon, color: estado.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pedido.idCorto,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        _EstadoBadge(estado: estado),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // resumenLinea omite lo vacío: un prediseñado no
                      // tiene tamaño, y antes quedaba un "·" colgando.
                      pedido.resumenLinea,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          fecha,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$ ${fmt.format(pedido.total)} COP',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF0E8498),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final EstadoPedido estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: estado.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: estado.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        estado.label,
        style: TextStyle(
          color: estado.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
