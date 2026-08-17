import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/core/models/pedido_admin.dart';
import 'package:yogo_vital_app/core/services/user_role_service.dart';
import 'package:yogo_vital_app/data/repositories/pedidos_admin_repository.dart';
import 'package:yogo_vital_app/presentation/pages/admin/pedido_admin_detalle_screen.dart';
import 'package:yogo_vital_app/presentation/widgets/notification_bell.dart';

const _kBlue = Color(0xFF5B9EF5);
const _kBg = Color(0xFFF5F7FA);
const _kCard = Colors.white;
const _kDanger = Color(0xFFEF5350);

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _repo = PedidosAdminRepository();

  bool _checking = true;
  DateTime? _desde;
  DateTime? _hasta;
  Stream<List<PedidoAdmin>>? _stream;
  Map<String, int> _contadores = {};

  /// Ids de pedidos ya vistos en esta sesión de pantalla.
  ///
  /// El stream de Realtime reemite la lista entera en cada cambio, no solo
  /// lo que cambió. Para saber qué es realmente nuevo hay que compararlo
  /// con lo que ya se había visto.
  final Set<String> _pedidosVistos = {};

  /// La primera emisión trae todos los pedidos existentes. Sin esta
  /// bandera sonaría la alarma al abrir la pantalla, como si acabaran de
  /// entrar cincuenta pedidos.
  bool _primeraCarga = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final isAdmin = await UserRoleService.isAdmin();
    if (!mounted) return;
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acceso restringido: solo administradores'),
          backgroundColor: _kDanger,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }
    _loadContadores();
    setState(() {
      _checking = false;
      _stream = _repo.streamTodosPedidos();
    });
  }

  Future<void> _loadContadores() async {
    final c = await _repo.getContadoresEstado();
    if (mounted) setState(() => _contadores = c);
  }

  void _aplicarFiltro() {
    setState(() {
      _stream = _repo.streamTodosPedidos(desde: _desde, hasta: _hasta);
    });
    _loadContadores();
  }

  Future<void> _seleccionarRango() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _desde != null && _hasta != null
          ? DateTimeRange(start: _desde!, end: _hasta!)
          : null,
      locale: const Locale('es'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _kBlue),
        ),
        child: child!,
      ),
    );
    if (rango != null) {
      _desde = rango.start;
      _hasta = rango.end;
      _aplicarFiltro();
    }
  }

  void _limpiarFiltro() {
    _desde = null;
    _hasta = null;
    _aplicarFiltro();
  }

  /// Avisa cuando entran pedidos nuevos con la pantalla abierta.
  ///
  /// La lista ya se actualizaba sola por Realtime, pero en silencio: si
  /// nadie estaba mirando el celular en ese momento, el pedido pasaba
  /// desapercibido. En un mostrador con una tablet, este sonido es lo que
  /// hace que alguien levante la vista.
  ///
  /// Se llama desde el builder del StreamBuilder, así que no puede tocar
  /// setState directamente — de ahí el addPostFrameCallback.
  void _detectarPedidosNuevos(List<PedidoAdmin> pedidos) {
    final nuevos = pedidos
        .where((p) => p.estadoRaw == 'Recibido')
        .where((p) => !_pedidosVistos.contains(p.id))
        .toList();

    _pedidosVistos.addAll(pedidos.map((p) => p.id));

    // Al abrir la pantalla todo es "nuevo": solo se registra, no se avisa.
    if (_primeraCarga) {
      _primeraCarga = false;
      return;
    }
    if (nuevos.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // SystemSound y HapticFeedback vienen con Flutter, sin dependencias.
      // En Android e iOS suenan y vibran; en web el navegador los ignora,
      // así que ahí solo queda el aviso visual. Si más adelante hace falta
      // un sonido más audible (un mostrador ruidoso), habría que añadir el
      // paquete audioplayers y un archivo de audio propio.
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nuevos.length == 1
                      ? 'Nuevo pedido de ${nuevos.first.clienteNombre}'
                      : '${nuevos.length} pedidos nuevos',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 6),
        ),
      );

      _loadContadores();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildContadores(),
            _buildFiltroBar(),
            Expanded(
              child: StreamBuilder<List<PedidoAdmin>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: _kBlue),
                    );
                  }
                  if (snap.hasError) {
                    return _buildError(snap.error.toString());
                  }
                  final pedidos = snap.data ?? [];
                  if (snap.hasData) _detectarPedidosNuevos(pedidos);
                  if (pedidos.isEmpty) return _buildEmpty();
                  return RefreshIndicator(
                    color: _kBlue,
                    onRefresh: () async {
                      _loadContadores();
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: pedidos.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (ctx, i) =>
                          _PedidoAdminCard(
                            pedido: pedidos[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PedidoAdminDetalleScreen(
                                  pedidoId: pedidos[i].id,
                                ),
                              ),
                            ).then((_) => _loadContadores()),
                          ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A8FE7), _kBlue],
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
            child: Text(
              'Pedidos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Desde la migración 0046 los administradores también reciben
          // notificaciones: una por cada pedido nuevo. La campana es la
          // misma del cliente, y aquí sirve para ver los pedidos que
          // entraron mientras la app estuvo cerrada — el Realtime de la
          // lista solo avisa a quien está mirando en ese momento.
          const NotificationBell(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('ADMIN',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildContadores() {
    if (_contadores.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _CounterChip(
              label: 'Recibidos',
              count: _contadores['Recibido'] ?? 0,
              color: EstadoPedido.recibido.color),
          _CounterChip(
              label: 'En prep.',
              count: _contadores['En preparación'] ?? 0,
              color: EstadoPedido.enPreparacion.color),
          _CounterChip(
              label: 'En camino',
              count: _contadores['En camino'] ?? 0,
              color: EstadoPedido.enCamino.color),
          _CounterChip(
              label: 'Entregados',
              count: _contadores['Entregado'] ?? 0,
              color: EstadoPedido.entregado.color),
        ],
      ),
    );
  }

  Widget _buildFiltroBar() {
    final hasFiltro = _desde != null || _hasta != null;
    final fmt = DateFormat('dd/MM/yy');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, color: _kBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _seleccionarRango,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: hasFiltro
                      ? _kBlue.withValues(alpha: 0.08)
                      : _kBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: hasFiltro ? _kBlue : Colors.grey.shade300),
                ),
                child: Text(
                  hasFiltro
                      ? '${fmt.format(_desde!)} — ${fmt.format(_hasta!)}'
                      : 'Filtrar por fecha',
                  style: TextStyle(
                    color: hasFiltro ? _kBlue : Colors.grey,
                    fontSize: 13,
                    fontWeight:
                        hasFiltro ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          if (hasFiltro) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: _kDanger, size: 20),
              onPressed: _limpiarFiltro,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No hay pedidos',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600)),
          if (_desde != null) ...[
            const SizedBox(height: 8),
            TextButton(
                onPressed: _limpiarFiltro,
                child: const Text('Quitar filtros')),
          ],
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: _kDanger),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kDanger)),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _CounterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CounterChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
        const SizedBox(height: 3),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _PedidoAdminCard extends StatelessWidget {
  final PedidoAdmin pedido;
  final VoidCallback onTap;
  const _PedidoAdminCard({required this.pedido, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final estado = pedido.estado;
    final fmt = NumberFormat('#,###', 'es_CO');
    final fecha = DateFormat('dd/MM/yy HH:mm').format(pedido.createdAt.toLocal());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: estado.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(estado.icon, color: estado.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Expanded y no Spacer: con estados largos como
                      // "En preparación" la fila no cabía y se recortaba.
                      Expanded(
                        child: Text(pedido.idCorto,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(width: 6),
                      _EstadoBadge(estado: estado),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(pedido.clienteNombre,
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 11, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(fecha,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500])),
                      ),
                      const SizedBox(width: 6),
                      Text('\$ ${fmt.format(pedido.total)} COP',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF0E8498))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
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
        color: estado.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: estado.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        estado.label,
        style: TextStyle(
            color: estado.color,
            fontSize: 10,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}
