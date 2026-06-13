-- Migración 0023: Admin puede ver la tabla usuarios (sin recursión RLS)
--
-- Problema: tras 0019/0022 la política de `usuarios` era solo
--   USING (id = auth.uid())
-- por lo que el admin no podía leer las filas de otros clientes. Al embeber
-- `usuarios!cliente_id(...)` desde `pedidos`, el panel admin recibía null
-- y mostraba "Sin nombre" para todos los pedidos ajenos.
--
-- No se puede usar `EXISTS (SELECT 1 FROM usuarios ...)` dentro de una política
-- de la propia tabla `usuarios`: reintroduce la recursión infinita (error 42P17).
--
-- Solución: función SECURITY DEFINER que evalúa el rol saltándose RLS, y una
-- política que la usa. Idempotente: se puede ejecutar varias veces.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

-- ── 1. Helper sin recursión (SECURITY DEFINER bypassa RLS de usuarios) ──────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM usuarios
    WHERE id = auth.uid() AND rol = 'administrador'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ── 2. Política de SELECT: dueño O admin ────────────────────────────────────
DROP POLICY IF EXISTS usuarios_select_own ON public.usuarios;
CREATE POLICY usuarios_select_own ON public.usuarios
  FOR SELECT
  USING (id = auth.uid() OR public.is_admin());

-- ── 3. Verificación ─────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'usuarios'
ORDER BY policyname;
