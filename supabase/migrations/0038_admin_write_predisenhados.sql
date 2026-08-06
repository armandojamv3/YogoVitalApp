-- Migration 0038: Restaurar permiso de escritura del admin en predisenhados
-- + corregir columnas obsoletas.
--
-- Causa raíz 1: la migración 0017 ("drop_all_rls_clean") eliminó TODAS las
-- políticas de `predisenhados` y solo recreó una de SELECT, sin restaurar
-- nunca el acceso de escritura para el administrador. Mismo bug que ya se
-- corrigió para `sabores` en la migración 0032.
--
-- Causa raíz 2: la migración 0021 marcó `sabor_id` y `tamano_id` como
-- NOT NULL en `predisenhados`, de un diseño anterior donde un prediseñado
-- estaba ligado a un sabor/tamaño puntual. El diseño actual (con la
-- columna `ingredientes` como lista libre) no usa esos campos, así que
-- los volvemos nullable para que el admin pueda crear prediseñados sin
-- necesitar esos datos.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

-- ── 1. Restaurar escritura del admin ──────────────────────────────────────
DROP POLICY IF EXISTS "admin_write_predisenhados" ON public.predisenhados;
CREATE POLICY "admin_write_predisenhados"
  ON public.predisenhados
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ── 2. Columnas obsoletas: volver a permitir NULL ─────────────────────────
ALTER TABLE public.predisenhados ALTER COLUMN sabor_id DROP NOT NULL;
ALTER TABLE public.predisenhados ALTER COLUMN tamano_id DROP NOT NULL;

-- ── Verificación ──────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'predisenhados'
ORDER BY policyname;
