-- Las migraciones 0016 y 0017 limpiaron TODAS las políticas de `sabores`
-- (para resolver un problema de recursión infinita) y solo dejaron una
-- política de SELECT para clientes (`activo = true`). Nunca se volvió a
-- crear una política que permita al administrador escribir (INSERT/UPDATE),
-- por lo que RLS bloquea en silencio cualquier intento de agregar/editar
-- un sabor: la operación afecta 0 filas en vez de dar un error de permiso
-- explícito (de ahí "Cannot coerce the result to a single JSON object").
--
-- Reusa public.is_admin() (SECURITY DEFINER, ya usada en otras tablas
-- desde la migración 0015) para evitar el mismo problema de recursión.

DROP POLICY IF EXISTS "admin_write_sabores" ON public.sabores;

CREATE POLICY "admin_write_sabores"
  ON public.sabores
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
