-- Migration 0050: que "sin calificar" se pueda distinguir de "calificado con 5".
--
-- ── El problema ──────────────────────────────────────────────────────────
-- `sabores.calificacion_promedio` se creó (0033 y SUPABASE_SETUP.sql) como:
--
--     calificacion_promedio NUMERIC(3,2) NOT NULL DEFAULT 5.0
--
-- Es decir: todo sabor nace con la nota máxima escrita en la fila. Y el
-- trigger `actualizar_promedio_sabor()` reforzaba lo mismo con
-- `COALESCE(AVG(c.estrellas), 5.0)`.
--
-- El resultado es que la app mostraba 5 estrellas en productos que nadie
-- había probado. Eso engaña al cliente, y además borra la información que
-- más te interesa a ti: si todo marca 5.0, no hay forma de ver qué gusta y
-- qué no. Peor aún, la primera calificación real casi siempre BAJA la nota,
-- que es justo lo contrario de lo que debería pasar.
--
-- ── La corrección ────────────────────────────────────────────────────────
-- NULL pasa a significar "todavía nadie lo ha calificado". La app ya sabe
-- leerlo: cuando llega NULL no dibuja estrellas.

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  1. LA COLUMNA ADMITE NULL Y DEJA DE RELLENARSE SOLA                 ║
-- ╚══════════════════════════════════════════════════════════════════════╝
ALTER TABLE public.sabores
  ALTER COLUMN calificacion_promedio DROP DEFAULT;

ALTER TABLE public.sabores
  ALTER COLUMN calificacion_promedio DROP NOT NULL;

COMMENT ON COLUMN public.sabores.calificacion_promedio IS
  'Promedio de estrellas. NULL = sin calificaciones todavía. Lo mantiene '
  'al día el trigger trg_actualizar_promedio_sabor; no se escribe a mano.';

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  2. RECALCULAR LO QUE YA HAY                                         ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Se recalculan TODOS los sabores desde la tabla `calificaciones`, que es
-- la única fuente real. Los que no tengan ninguna quedan en NULL.
UPDATE public.sabores s
   SET calificacion_promedio = sub.promedio
  FROM (
    SELECT s2.id,
           ROUND(AVG(c.estrellas)::numeric, 2) AS promedio
      FROM public.sabores s2
      LEFT JOIN public.pedidos p       ON p.sabor_id = s2.id
      LEFT JOIN public.calificaciones c ON c.pedido_id = p.id
     GROUP BY s2.id
  ) AS sub
 WHERE s.id = sub.id;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  3. EL TRIGGER DEJA DE INVENTAR EL 5.0                               ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Igual que la versión de 0048, pero sin el COALESCE(..., 5.0): si no hay
-- calificaciones, AVG devuelve NULL y NULL es la respuesta correcta.
CREATE OR REPLACE FUNCTION public.actualizar_promedio_sabor()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sabor_id UUID;
  v_promedio NUMERIC(3,2);
BEGIN
  SELECT sabor_id INTO v_sabor_id FROM pedidos WHERE id = NEW.pedido_id;
  IF v_sabor_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT ROUND(AVG(c.estrellas)::numeric, 2) INTO v_promedio
    FROM calificaciones c
    JOIN pedidos p ON p.id = c.pedido_id
   WHERE p.sabor_id = v_sabor_id;

  UPDATE sabores SET calificacion_promedio = v_promedio
   WHERE id = v_sabor_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_actualizar_promedio_sabor ON public.calificaciones;
CREATE TRIGGER trg_actualizar_promedio_sabor
  AFTER INSERT OR UPDATE ON public.calificaciones
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_promedio_sabor();

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  4. COMPROBACIÓN                                                     ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Debe devolver una fila por sabor. `promedio` en NULL en los que nadie ha
-- calificado, y `votos` a 0 en esos mismos.
--
--   SELECT s.nombre,
--          s.calificacion_promedio AS promedio,
--          COUNT(c.id)             AS votos
--     FROM public.sabores s
--     LEFT JOIN public.pedidos p        ON p.sabor_id = s.id
--     LEFT JOIN public.calificaciones c ON c.pedido_id = p.id
--    GROUP BY s.id, s.nombre, s.calificacion_promedio
--    ORDER BY votos DESC, s.nombre;
