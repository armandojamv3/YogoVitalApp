-- Migration 0039: predisenhados.precio ya no es obligatorio.
--
-- Columna heredada del diseño viejo (junto con sabor_id/tamano_id que ya
-- se corrigieron en la migración 0038). El diseño actual usa `precio_total`
-- en su lugar; `precio` quedó como columna muerta pero seguía exigiendo
-- NOT NULL, así que el INSERT del admin fallaba con:
--   "null value in column 'precio' violates not-null constraint"
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

ALTER TABLE public.predisenhados ALTER COLUMN precio DROP NOT NULL;
