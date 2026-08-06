-- Migration 0028: Notificaciones in-app + reconciliar RLS de admin.
--
-- Contexto:
--   El sistema de push notifications (Edge Function send-notification vía
--   FCM) nunca quedó realmente conectado: la app no integra Firebase, nadie
--   guarda un fcm_token de dispositivo, y además el endpoint legacy de FCM
--   que usa la función ya fue dado de baja por Google. En vez de depender
--   de un servicio externo, se agrega un sistema de notificaciones dentro
--   de la propia app (tabla + Realtime), que sí es 100% funcional con lo
--   que ya está montado (Supabase).
--
--   De paso, se reconcilia un hueco real encontrado en las políticas RLS
--   versionadas: la 0018/0019 dejaron "pedidos_update_own" e
--   "historial_insert" restringidas a cliente_id = auth.uid(), sin agregar
--   nunca una política que permita al ADMIN actualizar el pedido de otro
--   usuario ni insertar su historial de estados — que es exactamente lo
--   que hace PedidosAdminRepository.cambiarEstado(). Es posible que esto
--   ya se haya parchado directo en el dashboard de Supabase (como pasó
--   antes con metodo_pago y admin_id, ver migraciones 0020 y 0026), pero
--   como no queda versionado en ningún lado, se reconcilia aquí también
--   de forma idempotente para no depender de eso.

-- ── 1. Tabla notificaciones ─────────────────────────────────────────────
-- La tabla YA EXISTÍA en Supabase (de un sprint anterior que nunca se
-- terminó de conectar), con este esquema real — confirmado por consulta
-- a information_schema.columns:
--   id UUID, usuario_id UUID, pedido_id UUID, titulo TEXT, mensaje TEXT,
--   tipo TEXT, leida BOOLEAN, created_at TIMESTAMPTZ.
-- (Ojo: es "usuario_id"/"leida", NO "cliente_id"/"leido" como en el resto
-- del proyecto — se respeta el nombre real de la columna existente.)
-- Se crea solo por si en algún ambiente nuevo no existiera todavía.
CREATE TABLE IF NOT EXISTS public.notificaciones (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id  UUID REFERENCES public.usuarios(id) ON DELETE CASCADE,
  pedido_id   UUID REFERENCES public.pedidos(id) ON DELETE CASCADE,
  titulo      TEXT,
  mensaje     TEXT,
  tipo        TEXT,
  leida       BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE pol TEXT;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notificaciones'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.notificaciones', pol);
  END LOOP;
END $$;

-- El cliente solo ve sus propias notificaciones.
CREATE POLICY "notificaciones_select_own"
  ON public.notificaciones FOR SELECT
  USING (usuario_id = auth.uid());

-- El cliente solo puede marcar sus propias notificaciones como leídas.
CREATE POLICY "notificaciones_update_own"
  ON public.notificaciones FOR UPDATE
  USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

-- Cualquier usuario autenticado (el admin, al cambiar un estado) puede
-- crear una notificación para otro cliente. No cruza a `usuarios` para
-- evitar el mismo tipo de recursión de RLS ya resuelto en 0018/0019.
CREATE POLICY "notificaciones_insert_authenticated"
  ON public.notificaciones FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- ── 2. Reconciliar: admin puede actualizar el estado de cualquier pedido ──
DROP POLICY IF EXISTS "pedidos_update_admin" ON public.pedidos;

CREATE POLICY "pedidos_update_admin"
  ON public.pedidos FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM usuarios
      WHERE id = auth.uid() AND rol = 'administrador'
    )
  );

-- ── 3. Reconciliar: admin puede insertar historial de estados ───────────
DROP POLICY IF EXISTS "historial_insert_admin" ON public.historial_estados;

CREATE POLICY "historial_insert_admin"
  ON public.historial_estados FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM usuarios
      WHERE id = auth.uid() AND rol = 'administrador'
    )
  );
