-- Migración 0026: Agregar admin_id a historial_estados (reconciliación de schema)
-- Objetivo:
--   La 0010 declaró admin_id como BIGINT REFERENCES users(id) (esquema legacy),
--   pero la BD real quedó sin la columna tras la migración a Supabase Auth.
--   Aquí se reconcilia añadiéndola como UUID que referencia a usuarios(id),
--   para registrar qué administrador hizo cada cambio de estado (RNF09).

-- Idempotente: no falla si la columna ya existe.
ALTER TABLE historial_estados
  ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES usuarios(id);
