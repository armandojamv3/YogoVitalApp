-- Migration 0033: Agregar columna faltante calificacion_promedio en sabores.
--
-- Root cause: la columna está definida en SUPABASE_SETUP.sql (línea 90) pero
-- nunca se aplicó en la base de datos real. Al calificar un pedido, un
-- trigger/función en Supabase (creado manualmente desde el dashboard, no
-- versionado) intenta actualizar sabores.calificacion_promedio y falla con:
--   "column calificacion_promedio of relation sabores does not exist"
--
-- Mismo patrón que la migración 0031 (imagen_url): columnas del baseline
-- que quedaron fuera de sync con la base real.
--
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run

ALTER TABLE public.sabores
  ADD COLUMN IF NOT EXISTS calificacion_promedio NUMERIC(3,2) NOT NULL DEFAULT 5.0;
