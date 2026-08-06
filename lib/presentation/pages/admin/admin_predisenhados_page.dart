import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/models/predisenhado_admin_provider.dart';
import 'package:yogo_vital_app/core/models/predisenhado_model.dart';
import 'package:yogo_vital_app/core/services/user_role_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Paleta de colores del módulo admin de prediseñados (mismo estilo que Sabores)
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF5B9EF5);
const _kAccent = Color(0xFF0E8498);
const _kBg = Color(0xFFF5F7FA);
const _kCard = Colors.white;
const _kDanger = Color(0xFFEF5350);
const _kSuccess = Color(0xFF4CAF50);

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL – Lista de prediseñados (admin)
// ─────────────────────────────────────────────────────────────────────────────

class AdminPredisenhadosPage extends StatefulWidget {
  const AdminPredisenhadosPage({super.key});

  @override
  State<AdminPredisenhadosPage> createState() => _AdminPredisenhadosPageState();
}

class _AdminPredisenhadosPageState extends State<AdminPredisenhadosPage> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
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
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => PredisenhadoAdminProvider()..cargarPredisenhados(),
      child: const _AdminPredisenhadosView(),
    );
  }
}

class _AdminPredisenhadosView extends StatelessWidget {
  const _AdminPredisenhadosView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Consumer<PredisenhadoAdminProvider>(
                builder: (ctx, prov, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (prov.formSuccess != null) {
                      _showSnack(context, prov.formSuccess!, isError: false);
                      prov.resetFormState();
                    } else if (prov.formState == PredisenhadoFormState.error &&
                        prov.formError != null) {
                      _showSnack(context, prov.formError!, isError: true);
                      prov.resetFormState();
                    }
                  });
                  return _buildBody(ctx, prov);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A8FE7), _kPrimary],
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
              'Gestión de Prediseñados',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'ADMIN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, PredisenhadoAdminProvider prov) {
    if (prov.loadingList) {
      return const Center(
        child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 3),
      );
    }

    if (prov.listError != null) {
      return _buildListError(context, prov);
    }

    if (prov.predisenhados.isEmpty) {
      return _buildEmpty(context);
    }

    return RefreshIndicator(
      color: _kPrimary,
      onRefresh: prov.cargarPredisenhados,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: prov.predisenhados.length,
        itemBuilder: (ctx, i) => _PredisenhadoCard(
          p: prov.predisenhados[i],
          onEdit: () => _navegarFormulario(ctx, p: prov.predisenhados[i]),
          onDelete: () => _confirmarEliminacion(ctx, prov.predisenhados[i]),
        ),
      ),
    );
  }

  Widget _buildListError(BuildContext context, PredisenhadoAdminProvider prov) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 56, color: _kDanger),
          const SizedBox(height: 16),
          Text(
            prov.listError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF5A5A5A), fontSize: 15),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: prov.cargarPredisenhados,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.icecream_rounded,
                size: 48, color: _kPrimary),
          ),
          const SizedBox(height: 20),
          const Text(
            'No hay prediseñados registrados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toca el botón + para agregar el primer prediseñado',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────────────────────

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _navegarFormulario(context),
      backgroundColor: _kAccent,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Nuevo prediseñado',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  // ── Navegación y diálogos ─────────────────────────────────────────────────

  void _navegarFormulario(BuildContext context, {PredisenhadoModel? p}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<PredisenhadoAdminProvider>(),
          child: PredisenhadoFormPage(predisenhadoAEditar: p),
        ),
      ),
    );
  }

  Future<void> _confirmarEliminacion(
      BuildContext context, PredisenhadoModel p) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '¿Eliminar prediseñado?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '¿Eliminar el prediseñado "${p.nombre}"?\nDejará de mostrarse a los clientes.',
          style: const TextStyle(color: Color(0xFF5A5A5A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado == true && context.mounted) {
      await context.read<PredisenhadoAdminProvider>().eliminarPredisenhado(p.id);
    }
  }

  void _showSnack(BuildContext ctx, String msg, {required bool isError}) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: isError ? _kDanger : _kSuccess,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Tarjeta de prediseñado en la lista
// ─────────────────────────────────────────────────────────────────────────────

class _PredisenhadoCard extends StatelessWidget {
  final PredisenhadoModel p;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PredisenhadoCard({
    required this.p,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_CO');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: p.activo
                      ? [_kPrimary.withValues(alpha: 0.15), _kPrimary.withValues(alpha: 0.25)]
                      : [Colors.grey.shade200, Colors.grey.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: (p.imagenUrl != null && p.imagenUrl!.isNotEmpty)
                    ? Image.network(
                        p.imagenUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.icecream_rounded,
                          color: p.activo ? _kPrimary : Colors.grey,
                          size: 28,
                        ),
                      )
                    : Icon(
                        Icons.icecream_rounded,
                        color: p.activo ? _kPrimary : Colors.grey,
                        size: 28,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.nombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (p.esNuevo) _buildTag('Nuevo', const Color(0xFF2196F3)),
                      if (p.esPopular) ...[
                        const SizedBox(width: 4),
                        _buildTag('Popular', const Color(0xFFFF9800)),
                      ],
                      const SizedBox(width: 4),
                      _StatusBadge(activo: p.activo),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF6B6B7B)),
                  ),
                  if (p.ingredientes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      p.ingredientes.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF9AA0A6)),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'COP ${fmt.format(p.precioTotal)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kAccent,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _ActionIconBtn(
                        icon: Icons.edit_rounded,
                        color: _kPrimary,
                        tooltip: 'Editar',
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 8),
                      _ActionIconBtn(
                        icon: Icons.delete_outline_rounded,
                        color: _kDanger,
                        tooltip: 'Eliminar',
                        onTap: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool activo;
  const _StatusBadge({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: activo
            ? _kSuccess.withValues(alpha: 0.12)
            : _kDanger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: activo ? _kSuccess : _kDanger,
        ),
      ),
    );
  }
}

class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA: Formulario agregar / editar prediseñado
// ─────────────────────────────────────────────────────────────────────────────

class PredisenhadoFormPage extends StatefulWidget {
  final PredisenhadoModel? predisenhadoAEditar;
  const PredisenhadoFormPage({super.key, this.predisenhadoAEditar});

  @override
  State<PredisenhadoFormPage> createState() => _PredisenhadoFormPageState();
}

class _PredisenhadoFormPageState extends State<PredisenhadoFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _ingredientesCtrl;

  bool _esPopular = false;
  bool _esNuevo = false;

  String? _imagenUrlExistente;
  Uint8List? _imagenNuevaBytes;
  String? _imagenNuevaNombre;
  bool _subiendoImagen = false;

  bool get _esEdicion => widget.predisenhadoAEditar != null;

  @override
  void initState() {
    super.initState();
    final p = widget.predisenhadoAEditar;
    _nombreCtrl = TextEditingController(text: p?.nombre ?? '');
    _descripcionCtrl = TextEditingController(text: p?.descripcion ?? '');
    _precioCtrl = TextEditingController(
      text: p != null ? p.precioTotal.toStringAsFixed(0) : '',
    );
    _ingredientesCtrl =
        TextEditingController(text: p?.ingredientes.join(', ') ?? '');
    _esPopular = p?.esPopular ?? false;
    _esNuevo = p?.esNuevo ?? false;
    _imagenUrlExistente = p?.imagenUrl;
  }

  Future<void> _seleccionarImagen() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imagenNuevaBytes = bytes;
      _imagenNuevaNombre = picked.name;
    });
  }

  Widget _buildPreviewImagen() {
    if (_imagenNuevaBytes != null) {
      return Image.memory(_imagenNuevaBytes!, fit: BoxFit.cover);
    }
    if (_imagenUrlExistente != null && _imagenUrlExistente!.isNotEmpty) {
      return Image.network(
        _imagenUrlExistente!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
            Icons.icecream_rounded, color: Colors.white, size: 40),
      );
    }
    return const Center(
      child: Icon(Icons.icecream_rounded, color: Colors.white, size: 40),
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _ingredientesCtrl.dispose();
    super.dispose();
  }

  List<String> get _ingredientesList => _ingredientesCtrl.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final prov = context.read<PredisenhadoAdminProvider>();
    final nombre = _nombreCtrl.text.trim();
    final descripcion = _descripcionCtrl.text.trim();
    final precio = double.parse(_precioCtrl.text.trim().replaceAll(',', '.'));
    final ingredientes = _ingredientesList;

    String? imagenUrl = _imagenUrlExistente;
    if (_imagenNuevaBytes != null) {
      setState(() => _subiendoImagen = true);
      try {
        imagenUrl = await prov.repository.uploadImagen(
          _imagenNuevaBytes!,
          _imagenNuevaNombre ?? 'predisenhado.jpg',
        );
      } catch (e) {
        if (mounted) {
          setState(() => _subiendoImagen = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: _kDanger),
          );
        }
        return;
      }
      if (mounted) setState(() => _subiendoImagen = false);
    }

    bool ok;
    if (_esEdicion) {
      ok = await prov.actualizarPredisenhado(
        id: widget.predisenhadoAEditar!.id,
        nombre: nombre,
        descripcion: descripcion,
        ingredientes: ingredientes,
        precioTotal: precio,
        imagenUrl: imagenUrl,
        esPopular: _esPopular,
        esNuevo: _esNuevo,
      );
    } else {
      ok = await prov.agregarPredisenhado(
        nombre: nombre,
        descripcion: descripcion,
        ingredientes: ingredientes,
        precioTotal: precio,
        imagenUrl: imagenUrl,
        esPopular: _esPopular,
        esNuevo: _esNuevo,
      );
    }

    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _subiendoImagen ? null : _seleccionarImagen,
                          child: Stack(
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4A8FE7),
                                      Color(0xFF5B9EF5),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _kPrimary.withValues(alpha: 0.35),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipOval(child: _buildPreviewImagen()),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: _kAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _subiendoImagen
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Icon(Icons.camera_alt_rounded,
                                          color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'Toca para elegir una foto',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          _esEdicion ? 'Editar prediseñado' : 'Nuevo prediseñado',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      _buildLabel('Nombre *'),
                      const SizedBox(height: 6),
                      _StyledField(
                        controller: _nombreCtrl,
                        hintText: 'Ej: Combo Tropical, Especial Frutos Rojos…',
                        prefixIcon: Icons.label_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          if (v.trim().length < 2) {
                            return 'Mínimo 2 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      _buildLabel('Descripción *'),
                      const SizedBox(height: 6),
                      _StyledField(
                        controller: _descripcionCtrl,
                        hintText: 'Describe el prediseñado brevemente…',
                        prefixIcon: Icons.description_rounded,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'La descripción es obligatoria';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      _buildLabel('Ingredientes (separados por coma)'),
                      const SizedBox(height: 6),
                      _StyledField(
                        controller: _ingredientesCtrl,
                        hintText: 'Ej: Fresa, Granola, Miel',
                        prefixIcon: Icons.grain_rounded,
                        maxLines: 2,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),

                      _buildLabel('Precio total (COP) *'),
                      const SizedBox(height: 6),
                      _StyledField(
                        controller: _precioCtrl,
                        hintText: 'Ej: 12000',
                        prefixIcon: Icons.attach_money_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]')),
                        ],
                        textInputAction: TextInputAction.done,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'El precio es obligatorio';
                          }
                          final parsed = double.tryParse(
                              v.trim().replaceAll(',', '.'));
                          if (parsed == null) {
                            return 'Ingresa un número válido';
                          }
                          if (parsed <= 0) {
                            return 'El precio debe ser mayor a 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _esPopular,
                              onChanged: (v) => setState(() => _esPopular = v),
                              activeColor: const Color(0xFFFF9800),
                              title: const Text('Popular',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _esNuevo,
                              onChanged: (v) => setState(() => _esNuevo = v),
                              activeColor: const Color(0xFF2196F3),
                              title: const Text('Nuevo',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Consumer<PredisenhadoAdminProvider>(
                        builder: (ctx, prov, _) {
                          if (prov.formState == PredisenhadoFormState.error &&
                              prov.formError != null) {
                            return _ErrorBanner(message: prov.formError!);
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      Consumer<PredisenhadoAdminProvider>(
                        builder: (ctx, prov, _) => _SubmitButton(
                          label: _esEdicion
                              ? 'Guardar cambios'
                              : 'Agregar prediseñado',
                          isLoading: prov.isSaving,
                          onPressed: _submit,
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
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
          colors: [Color(0xFF4A8FE7), _kPrimary],
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
          Expanded(
            child: Text(
              _esEdicion ? 'Editar prediseñado' : 'Agregar prediseñado',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A2E),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES REUTILIZABLES (mismo estilo que Sabores)
// ─────────────────────────────────────────────────────────────────────────────

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;

  const _StyledField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction = TextInputAction.next,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(prefixIcon, color: _kPrimary, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kDanger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kDanger, width: 2),
        ),
        errorStyle: const TextStyle(color: _kDanger, fontSize: 12),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kDanger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kDanger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _kDanger, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _kDanger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      decoration: BoxDecoration(
        gradient: isLoading
            ? null
            : const LinearGradient(
                colors: [Color(0xFF4A8FE7), _kPrimary],
              ),
        color: isLoading ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isLoading
            ? null
            : [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.grey,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
