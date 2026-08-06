-- La tabla `sabores` en producción fue creada/editada sin la columna
-- `imagen_url` que sí estaba definida en la migración original 0009
-- (patrón recurrente en este proyecto: columnas agregadas a mano en el
-- dashboard sin quedar reflejadas en migraciones versionadas).
--
-- Esta migración agrega la columna que usa la nueva función de subida
-- de imágenes de sabores (admin) para que coincida con el esquema real.

ALTER TABLE sabores ADD COLUMN IF NOT EXISTS imagen_url TEXT;
