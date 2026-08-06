-- Migration 0037: Agregar columnas faltantes en predisenhados.
--
-- Mismo patrón que las migraciones 0031 (imagen_url en sabores) y 0033
-- (calificacion_promedio en sabores): SUPABASE_SETUP.sql define estas
-- columnas para `predisenhados`, pero nunca se aplicaron en la base real.
-- Al intentar crear un prediseñado desde el nuevo panel admin, salió:
--   "Could not find the 'es_nuevo' column of 'predisenhados' in the schema cache"
--
-- Agregamos todas las columnas que PredisenhadoModel/PredisenhadosAdminRepository
-- esperan, por si faltara más de una.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

ALTER TABLE public.predisenhados
  ADD COLUMN IF NOT EXISTS ingredientes JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS precio_total NUMERIC(10,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS imagen_url TEXT,
  ADD COLUMN IF NOT EXISTS es_popular BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS es_nuevo BOOLEAN NOT NULL DEFAULT false;
