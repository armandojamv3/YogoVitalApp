-- Migration 0036: Limpieza — eliminar política UPDATE duplicada en pedidos.
--
-- Al correr la migración 0035 apareció "pedidos_update_admin" (creada en la
-- migración 0028) todavía activa junto a la nueva "pedidos_update". No es
-- una vulnerabilidad: "pedidos_update_admin" solo concede acceso cuando
-- quien llama YA es administrador (su USING vuelve a verificar el rol en
-- cada fila), así que nunca le da nada extra a un cliente normal. Pero es
-- redundante — la nueva "pedidos_update" ya cubre el caso admin — y tener
-- dos políticas de UPDATE para la misma tabla es confuso de mantener.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

DROP POLICY IF EXISTS "pedidos_update_admin" ON public.pedidos;

-- ── Verificación: debe quedar solo "pedidos_update" para UPDATE ──────────
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'pedidos'
ORDER BY policyname;
