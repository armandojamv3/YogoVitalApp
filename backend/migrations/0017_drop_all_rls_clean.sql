-- Migration 0017: Elimina TODAS las políticas de sabores y predisenhados
-- de forma dinámica (sin importar el nombre) y recrea políticas limpias.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

-- ── 1. Eliminar TODAS las políticas de sabores (cualquier nombre) ─────────
DO $$
DECLARE
    pol TEXT;
BEGIN
    FOR pol IN
        SELECT policyname
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'sabores'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.sabores', pol);
    END LOOP;
END $$;

-- Política única sin dependencias externas
CREATE POLICY "sabores_select"
  ON public.sabores FOR SELECT
  USING (activo = true);

-- ── 2. Eliminar TODAS las políticas de predisenhados (cualquier nombre) ───
DO $$
DECLARE
    pol TEXT;
BEGIN
    FOR pol IN
        SELECT policyname
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'predisenhados'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.predisenhados', pol);
    END LOOP;
END $$;

-- Política única sin dependencias externas
CREATE POLICY "predisenhados_select"
  ON public.predisenhados FOR SELECT
  USING (activo = true);

-- ── 3. Eliminar función is_admin() si existe (ya no la necesitamos) ───────
DROP FUNCTION IF EXISTS public.is_admin();

-- ── Verificación: muestra las políticas activas después del fix ───────────
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('sabores', 'predisenhados')
ORDER BY tablename, policyname;
