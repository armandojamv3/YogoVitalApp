-- Migration 0016: Limpia todas las políticas conflictivas de sabores
-- y deja solo una política simple que no depende de otras tablas.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

-- Elimina TODAS las políticas actuales de sabores
DROP POLICY IF EXISTS "admin_all_sabores"      ON public.sabores;
DROP POLICY IF EXISTS "cliente_select_sabores" ON public.sabores;
DROP POLICY IF EXISTS "sabores_select"         ON public.sabores;

-- Política única: usuarios autenticados ven sabores activos
-- (sin JOIN a otras tablas → sin riesgo de recursión ni errores 500)
CREATE POLICY "sabores_select" ON public.sabores
  FOR SELECT USING (activo = true);

-- Política para administradores: se añadirá cuando la tabla usuarios
-- esté completamente configurada y sin recursión.
