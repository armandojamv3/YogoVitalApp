-- Migration 0047: cancelar_pedido() — cancelación atómica y con aviso al
-- administrador.
--
-- ── LO QUE PASABA ───────────────────────────────────────────────────────
-- cancelarPedido() en el repositorio hacía tres cosas sueltas:
--   1. SELECT del estado, para comprobar que siga en 'Recibido'.
--   2. UPDATE del pedido a 'Cancelado'.
--   3. INSERT en historial_estados.
--
-- Tres problemas:
--
-- a) Nadie avisa al administrador. Si tiene la pantalla de pedidos abierta
--    verá el cambio por Realtime, en silencio; si no, se entera cuando
--    entre a mirar. En un negocio de comida eso significa que alguien puede
--    estar preparando un yogur que el cliente ya canceló.
--
-- b) No es atómico. Si falla el INSERT del historial, el pedido queda
--    cancelado sin ningún rastro de cuándo ni desde qué estado.
--
-- c) Hay una carrera con el administrador. Entre el SELECT que comprueba el
--    estado y el UPDATE que cancela, el admin puede haber movido el pedido a
--    'En preparación'. La política RLS de la 0042 lo impide (compara el
--    estado previo), así que no llegaba a corromperse nada, pero el error
--    que veía el cliente era genérico en vez de "ya está en preparación".
--
-- ── LA SOLUCIÓN ─────────────────────────────────────────────────────────
-- Una función cancelar_pedido() que hace las tres cosas más el aviso en una
-- sola transacción, y que bloquea la fila (SELECT ... FOR UPDATE) mientras
-- decide. Así el administrador no puede colarse a mitad de la operación:
-- quien llegue segundo espera y ve el estado real.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente.

CREATE OR REPLACE FUNCTION public.cancelar_pedido(p_pedido_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_estado  TEXT;
  v_total   NUMERIC;
  v_cliente TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  -- FOR UPDATE bloquea la fila hasta el final de la transacción. Es lo que
  -- cierra la carrera con el administrador: si él está cambiando el estado
  -- en este mismo instante, uno de los dos espera al otro y ve el estado
  -- que quedó de verdad, no el que leyó hace un momento.
  SELECT estado, total INTO v_estado, v_total
    FROM pedidos
   WHERE id = p_pedido_id AND cliente_id = v_uid
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El pedido no existe o no es tuyo';
  END IF;

  IF v_estado = 'Cancelado' THEN
    RAISE EXCEPTION 'Este pedido ya estaba cancelado';
  END IF;

  IF v_estado <> 'Recibido' THEN
    RAISE EXCEPTION 'Este pedido ya está en proceso y no puede ser cancelado.';
  END IF;

  UPDATE pedidos
     SET estado = 'Cancelado',
         updated_at = now()
   WHERE id = p_pedido_id;

  INSERT INTO historial_estados (pedido_id, estado_anterior, estado_nuevo)
  VALUES (p_pedido_id, 'Recibido', 'Cancelado');

  -- Aviso a los administradores, igual que en crear_pedido() (0046).
  SELECT nombre INTO v_cliente FROM usuarios WHERE id = v_uid;

  INSERT INTO notificaciones (usuario_id, pedido_id, titulo, mensaje, tipo, leida)
  SELECT u.id,
         p_pedido_id,
         'Pedido cancelado',
         COALESCE(v_cliente, 'Un cliente') || ' canceló el pedido #' ||
           upper(left(p_pedido_id::text, 8)) ||
           ' ($' || to_char(COALESCE(v_total, 0), 'FM999G999G999') || ')',
         'pedido_cancelado',
         FALSE
  FROM usuarios u
  WHERE u.rol = 'administrador';
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancelar_pedido(UUID) TO authenticated;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  CERRAR EL UPDATE DIRECTO DEL CLIENTE                                ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Cancelar era la única razón por la que un cliente necesitaba UPDATE sobre
-- `pedidos`. Ahora que va por la RPC, la política puede quedarse solo con
-- el administrador. Mismo razonamiento que la 0043 hizo con el INSERT.
--
-- Verificado antes de aplicar: los únicos UPDATE sobre pedidos en la app
-- son cambiarEstado() (admin, sigue funcionando) y cancelarPedido()
-- (migrado a esta RPC).
--
-- Si hubiera que revertirlo, la política anterior era la de la migración
-- 0042:
--   USING (cliente_id = auth.uid() OR public.is_admin())
--   WITH CHECK (public.is_admin() OR (cliente_id = auth.uid()
--               AND estado = 'Cancelado'
--               AND public.estado_pedido_previo(pedidos.id) = 'Recibido'))

DROP POLICY IF EXISTS "pedidos_update" ON public.pedidos;
CREATE POLICY "pedidos_update" ON public.pedidos FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());


-- ── Verificación ─────────────────────────────────────────────────────────
-- Correr después del COMMIT, una a la vez.

-- 1. La función existe y es SECURITY DEFINER
SELECT proname, prosecdef AS security_definer
FROM pg_proc WHERE proname = 'cancelar_pedido';

-- 2. Solo queda la política de UPDATE para admin
SELECT policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'pedidos' AND cmd = 'UPDATE';

-- 3. Avisos de cancelación generados (tras cancelar un pedido de prueba)
SELECT n.created_at, n.titulo, n.mensaje, u.nombre AS destinatario
FROM notificaciones n
JOIN usuarios u ON u.id = n.usuario_id
WHERE n.tipo = 'pedido_cancelado'
ORDER BY n.created_at DESC
LIMIT 10;
