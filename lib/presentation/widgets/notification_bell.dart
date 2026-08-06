import 'package:flutter/material.dart';
import 'package:yogo_vital_app/core/models/notificacion.dart';
import 'package:yogo_vital_app/data/repositories/notificaciones_repository.dart';
import 'package:yogo_vital_app/presentation/pages/notificaciones/notificaciones_page.dart';

/// Ícono de campana con contador de notificaciones no leídas, en tiempo
/// real (Supabase Realtime). Reemplaza al push notification que nunca
/// quedó conectado: esto sí avisa al usuario apenas abre la app.
class NotificationBell extends StatefulWidget {
  final Color color;

  const NotificationBell({super.key, this.color = Colors.white});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _repo = NotificacionesRepository();

  // Se reconstruye con una key nueva cada vez que volvemos de la pantalla
  // de notificaciones, forzando una nueva consulta que ya refleja el
  // "leida = true" recién guardado — no depende de que Supabase Realtime
  // emita el evento UPDATE (algunos proyectos solo tienen habilitado
  // INSERT en la publicación de Realtime, y entonces el contador nunca
  // se enteraría del cambio hasta reiniciar la app).
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Notificacion>>(
      key: ValueKey(_refreshKey),
      stream: _repo.streamNotificaciones(),
      builder: (context, snapshot) {
        final noLeidas =
            (snapshot.data ?? const []).where((n) => !n.leida).length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: widget.color),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificacionesPage()),
                );
                if (!mounted) return;
                setState(() => _refreshKey++);
              },
            ),
            if (noLeidas > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    noLeidas > 9 ? '9+' : '$noLeidas',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
