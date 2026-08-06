-- Migration 0042: Corrige "infinite recursion detected in policy for
-- relation 'pedidos'" al cambiar el estado de un pedido.
--
-- SÍNTOMA: después de aplicar la 0041 (que ya deja pasar el UPDATE del
-- trigger de total), el admin sigue sin poder cambiar el estado — ahora
-- con un error explícito:
--   "infinite recursion detected in policy for relation 'pedidos'"
--
-- CAUSA RAÍZ: la política "pedidos_update" (migración 0035) tiene, dentro
-- de su propio WITH CHECK, una subconsulta que vuelve a leer la tabla
-- `pedidos`:
--
--   (SELECT p2.estado FROM public.pedidos p2 WHERE p2.id = pedidos.id)
--
-- Postgres no evalúa OR con cortocircuito garantizado, así que aunque
-- is_admin() sea true, esa subconsulta se evalúa igual. Y como esa
-- subconsulta lee la MISMA tabla que la política está protegiendo, vuelve
-- a disparar la evaluación de las políticas de `pedidos` (en este caso, la
-- de SELECT), lo que Postgres detecta como recursión y aborta con error —
-- esto nunca se había visto antes porque, hasta la migración 0041, el
-- UPDATE fallaba primero por el bug del trigger de total.
--
-- FIX: mover esa lectura del estado anterior a una función SECURITY
-- DEFINER (mismo patrón que is_admin()). Al ejecutarse como el dueño de la
-- tabla, esa lectura interna no vuelve a pasar por RLS, así que no hay
-- ciclo.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente.

CREATE OR REPLACE FUNCTION public.estado_pedido_previo(p_pedido_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT estado FROM public.pedidos WHERE id = p_pedido_id;
$$;

GRANT EXECUTE ON FUNCTION public.estado_pedido_previo(UUID) TO authenticated;

DROP POLICY IF EXISTS "pedidos_update" ON public.pedidos;
CREATE POLICY "pedidos_update" ON public.pedidos FOR UPDATE
  USING (
    cliente_id = auth.uid()
    OR public.is_admin()
  )
  WITH CHECK (
    public.is_admin()
    OR (
      cliente_id = auth.uid()
      AND estado = 'Cancelado'
      AND public.estado_pedido_previo(pedidos.id) = 'Recibido'
    )
  );

-- ── Verificación ─────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'pedidos'
ORDER BY policyname;
