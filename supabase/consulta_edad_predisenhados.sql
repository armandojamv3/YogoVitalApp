-- Comprobación: edad real de los prediseñados y si les toca etiqueta "Nuevo".
--
-- Córrela en el SQL Editor de Supabase y pásame el resultado.
--
-- Qué mirar:
--   · dias_de_antiguedad = NULL  → la columna created_at no existe o está
--     vacía. Ese sería el fallo: sin fecha la app no puede caducar nada.
--   · dias_de_antiguedad < 30    → la etiqueta SÍ debe verse. No hay fallo.
--   · dias_de_antiguedad >= 30 y aun así se ve la etiqueta → ahí sí hay bug.

SELECT
  nombre,
  es_nuevo,
  created_at,
  EXTRACT(DAY FROM (now() - created_at))::int AS dias_de_antiguedad,
  CASE
    WHEN NOT es_nuevo                       THEN 'no (interruptor apagado)'
    WHEN created_at IS NULL                 THEN 'PROBLEMA: sin fecha de alta'
    WHEN now() - created_at < INTERVAL '30 days' THEN 'sí, todavía es nuevo'
    ELSE 'no, ya caducó'
  END AS deberia_verse_la_etiqueta
FROM public.predisenhados
ORDER BY created_at DESC NULLS FIRST;
