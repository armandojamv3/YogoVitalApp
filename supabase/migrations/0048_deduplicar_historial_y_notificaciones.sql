-- Migration 0048: dejar de duplicar el historial y las notificaciones.
--
-- ── CÓMO SE ENCONTRÓ ────────────────────────────────────────────────────
-- Revisando las funciones SECURITY DEFINER de la base aparecieron tres que
-- no existen en ninguna migración de este repositorio:
--
--   actualizar_promedio_sabor          → trigger sobre calificaciones
--   crear_notificacion_cambio_estado   → trigger sobre pedidos
--   registrar_cambio_estado            → trigger sobre pedidos
--
-- Es el quinto caso de desfase entre el repo y la base real, después de las
-- migraciones 0026, 0031, 0037 y 0044. Esta vez el desfase no era cosmético:
-- estaba duplicando datos.
--
-- ── LO QUE ESTABA PASANDO ───────────────────────────────────────────────
-- Los dos triggers sobre `pedidos` se disparan con cada cambio de estado y
-- escriben en historial_estados y en notificaciones. Pero el código de la
-- app hace exactamente lo mismo por su cuenta:
--
--   PedidosAdminRepository.cambiarEstado()  inserta historial + notificación
--   cancelar_pedido()  (migración 0047)     inserta historial
--
-- Resultado:
--   * Admin cambia un estado  → 2 filas de historial y 2 notificaciones
--     idénticas al cliente.
--   * Cliente cancela         → 2 filas de historial.
--
-- La duplicación de la cancelación la introdujo la propia migración 0047,
-- escrita sin saber que ese trigger existía.
--
-- ── CRITERIO DE LA SOLUCIÓN ─────────────────────────────────────────────
-- Se conservan los TRIGGERS y se quitan los INSERT del lado de la app.
--
-- El motivo: un trigger se dispara pase lo que pase — también si alguien
-- cambia un estado desde el editor SQL o desde una función futura. La
-- lógica en el repositorio solo cubre el camino que pasa por esa función
-- concreta. Para trazabilidad (RNF09), el trigger es la garantía más
-- fuerte de las dos.
--
-- ── ADEMÁS: admin_id mal asignado ───────────────────────────────────────
-- registrar_cambio_estado guardaba `admin_id = auth.uid()` siempre. Cuando
-- el que cambia el estado es el CLIENTE cancelando su pedido, quedaba su id
-- en una columna que existe para registrar qué administrador actuó
-- (ver migración 0026). Ahora solo se rellena si quien hace el cambio es
-- realmente un administrador.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente.

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  1. VERSIONAR LOS TRES TRIGGERS QUE FALTABAN                         ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Se recrean tal como están en la base (salvo el arreglo de admin_id), para
-- que una base creada desde cero con estas migraciones quede igual que la
-- real, y para que el próximo que lea el repo sepa que existen.

-- ── 1.1 Promedio de calificación por sabor ───────────────────────────────
-- Mantiene `sabores.calificacion_promedio` al día cuando entra una
-- calificación nueva. Sin cambios respecto a lo que ya hay.
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

  SELECT COALESCE(AVG(c.estrellas), 5.0) INTO v_promedio
    FROM calificaciones c
    JOIN pedidos p ON p.id = c.pedido_id
   WHERE p.sabor_id = v_sabor_id;

  UPDATE sabores SET calificacion_promedio = ROUND(v_promedio, 2)
   WHERE id = v_sabor_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_actualizar_promedio_sabor ON public.calificaciones;
CREATE TRIGGER trg_actualizar_promedio_sabor
  AFTER INSERT OR UPDATE ON public.calificaciones
  FOR EACH ROW EXECUTE FUNCTION public.actualizar_promedio_sabor();

-- ── 1.2 Notificación al cliente cuando cambia el estado ──────────────────
CREATE OR REPLACE FUNCTION public.crear_notificacion_cambio_estado()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mensaje TEXT;
BEGIN
  IF OLD.estado IS DISTINCT FROM NEW.estado THEN
    v_mensaje := CASE NEW.estado
      WHEN 'En preparación' THEN 'Tu yogur está siendo preparado 🍶'
      WHEN 'En camino'      THEN 'Tu pedido está en camino 🛵'
      WHEN 'Entregado'      THEN '¡Tu pedido ha llegado! Disfrútalo 🎉'
      WHEN 'Cancelado'      THEN 'Tu pedido fue cancelado'
      ELSE 'El estado de tu pedido cambió a: ' || NEW.estado
    END;

    INSERT INTO notificaciones (usuario_id, pedido_id, titulo, mensaje, tipo)
    VALUES (NEW.cliente_id, NEW.id, 'Actualización de pedido', v_mensaje,
            'estado_pedido');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_crear_notificacion_cambio_estado ON public.pedidos;
CREATE TRIGGER trg_crear_notificacion_cambio_estado
  AFTER UPDATE ON public.pedidos
  FOR EACH ROW EXECUTE FUNCTION public.crear_notificacion_cambio_estado();

-- ── 1.3 Historial de estados ─────────────────────────────────────────────
-- ÚNICO cambio funcional de esta migración: admin_id solo se rellena si
-- quien hace el cambio es administrador. Antes se guardaba auth.uid() a
-- secas, así que una cancelación hecha por el cliente dejaba su id en la
-- columna que identifica al administrador responsable.
CREATE OR REPLACE FUNCTION public.registrar_cambio_estado()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.estado IS DISTINCT FROM NEW.estado THEN
    INSERT INTO historial_estados
      (pedido_id, estado_anterior, estado_nuevo, fecha_cambio, admin_id)
    VALUES (
      NEW.id, OLD.estado, NEW.estado, now(),
      CASE WHEN public.is_admin() THEN auth.uid() ELSE NULL END
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_registrar_cambio_estado ON public.pedidos;
CREATE TRIGGER trg_registrar_cambio_estado
  AFTER UPDATE ON public.pedidos
  FOR EACH ROW EXECUTE FUNCTION public.registrar_cambio_estado();


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  2. cancelar_pedido() DEJA DE ESCRIBIR EL HISTORIAL                  ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- El UPDATE de estado que hace más abajo ya dispara
-- trg_registrar_cambio_estado. El INSERT que tenía la 0047 era la segunda
-- fila.
--
-- El aviso a los administradores SÍ se conserva: de eso no se encarga
-- ningún trigger.

CREATE OR REPLACE FUNCTION public.cancelar_pedido(p_pedido_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_estado  TEXT;
  v_total   NUMERIC;
  v_cliente TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  SELECT estado, total INTO v_estado, v_total
    FROM pedidos
   WHERE id = p_pedido_id AND cliente_id = v_uid
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El pedido no existe o no es tuyo';
  END IF;

  IF v_estado = 'Cancelado' THEN
    RAISE EXCEPTION 'Este pedido ya estaba cancelado';
  END IF;

  IF v_estado <> 'Recibido' THEN
    RAISE EXCEPTION 'Este pedido ya está en proceso y no puede ser cancelado.';
  END IF;

  -- Este UPDATE dispara los dos triggers: el del historial y el de la
  -- notificación al cliente. Por eso aquí ya no se inserta nada de eso.
  UPDATE pedidos
     SET estado = 'Cancelado',
         updated_at = now()
   WHERE id = p_pedido_id;

  -- Aviso a los administradores. Esto no lo cubre ningún trigger.
  SELECT nombre INTO v_cliente FROM usuarios WHERE id = v_uid;

  INSERT INTO notificaciones (usuario_id, pedido_id, titulo, mensaje, tipo, leida)
  SELECT u.id,
         p_pedido_id,
         'Pedido cancelado',
         COALESCE(v_cliente, 'Un cliente') || ' canceló el pedido #' ||
           upper(left(p_pedido_id::text, 8)) ||
           ' ($' || to_char(COALESCE(v_total, 0), 'FM999G999G999') || ')',
         'pedido_cancelado',
         FALSE
  FROM usuarios u
  WHERE u.rol = 'administrador';
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancelar_pedido(UUID) TO authenticated;


-- ── Verificación ─────────────────────────────────────────────────────────
-- Correr después del COMMIT, una a la vez.

-- 1. Pedidos con filas de historial duplicadas (misma transición, mismo
--    segundo). Son las que dejaron las duplicaciones anteriores.
--    Diagnóstico: NO se borran solas. Revísalas antes de decidir.
SELECT pedido_id, estado_anterior, estado_nuevo,
       date_trunc('second', fecha_cambio) AS momento,
       COUNT(*) AS veces
FROM historial_estados
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
ORDER BY momento DESC;

-- 2. Notificaciones duplicadas al mismo usuario por el mismo pedido.
SELECT usuario_id, pedido_id, mensaje,
       date_trunc('second', created_at) AS momento,
       COUNT(*) AS veces
FROM notificaciones
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
ORDER BY momento DESC;

-- 3. Historial con admin_id que en realidad es el cliente (dato viejo,
--    anterior al arreglo de esta migración).
SELECT h.id, h.pedido_id, h.estado_anterior, h.estado_nuevo, h.fecha_cambio,
       u.nombre AS registrado_como_admin, u.rol
FROM historial_estados h
JOIN usuarios u ON u.id = h.admin_id
WHERE u.rol <> 'administrador'
ORDER BY h.fecha_cambio DESC;
