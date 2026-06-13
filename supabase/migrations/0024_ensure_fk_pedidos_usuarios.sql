-- Migración 0024: Garantiza la FK pedidos.cliente_id → usuarios.id
--
-- Sin esta constraint, PostgREST no detecta la relación y falla el embed
-- `usuarios!cliente_id(...)` con:
--   "Could not find a relationship between 'pedidos' and 'usuarios'"
--
-- Postgres no soporta ADD CONSTRAINT IF NOT EXISTS para FKs, así que se
-- comprueba en pg_constraint antes de crearla. Idempotente.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t       ON t.oid = c.conrelid
    JOIN pg_namespace n   ON n.oid = t.relnamespace
    WHERE c.contype = 'f'
      AND n.nspname = 'public'
      AND t.relname = 'pedidos'
      AND c.conname = 'pedidos_cliente_id_fkey'
  ) THEN
    ALTER TABLE public.pedidos
      ADD CONSTRAINT pedidos_cliente_id_fkey
      FOREIGN KEY (cliente_id) REFERENCES public.usuarios(id)
      ON DELETE RESTRICT;
  END IF;
END $$;

-- Refresca el cache de esquema de PostgREST para que detecte la relación
NOTIFY pgrst, 'reload schema';

-- ── Verificación ────────────────────────────────────────────────────────────
SELECT conname, confrelid::regclass AS referencia
FROM pg_constraint
WHERE conrelid = 'public.pedidos'::regclass AND contype = 'f'
ORDER BY conname;
