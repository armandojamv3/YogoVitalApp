-- Migration 0035: Endurecimiento de seguridad — RNF08 (ISO 27001).
--
-- Corrige tres vulnerabilidades reales encontradas al revisar las políticas
-- RLS contra el código real de la app (no son teóricas, son explotables
-- llamando directamente a la API de Supabase con el anon key, sin pasar
-- por la app):
--
-- 1) ESCALAMIENTO DE PRIVILEGIOS: "usuarios_update_own" y "usuarios_insert_own"
--    solo validaban `id = auth.uid()`, sin restringir qué columnas se pueden
--    escribir. Cualquier cliente autenticado podía hacer
--      update usuarios set rol = 'administrador' where id = auth.uid()
--    y obtener acceso total al panel admin, porque is_admin() y
--    UserRoleService.isAdmin() solo leen esa misma columna.
--
-- 2) MANIPULACIÓN DE PRECIO: el total del pedido lo calcula Dart
--    (PedidoLocalModel.total) y se envía tal cual en el INSERT. La política
--    "pedidos_insert_own" solo valida cliente_id, no el total. Se podía
--    crear un pedido con total en 0 o cualquier cifra arbitraria.
--
-- 3) ESTADO DE PEDIDO SIN PROTECCIÓN: la política de UPDATE sobre pedidos
--    no tenía WITH CHECK, así que un cliente podía poner su propio pedido
--    en 'Entregado' directamente desde la API (sin pasar por el admin),
--    desbloqueando además una calificación falsa (esa política solo exige
--    estado = 'Entregado').
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente: se puede correr varias veces sin daño.


-- ── Asegurar que exista is_admin() (se usa en el resto de esta migración;
--    se redefine por si acaso, es idempotente y no cambia su comportamiento) ──
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios
    WHERE id = auth.uid() AND rol = 'administrador'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  1. BLOQUEAR CAMBIOS AL CAMPO `rol` DESDE LA API DE CLIENTE              ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- auth.uid() es NULL cuando la operación NO viene de PostgREST (por ejemplo,
-- el SQL Editor del dashboard, que corre como `postgres`). Ese sigue siendo
-- el único lugar legítimo para promover a un usuario a administrador —
-- la app no tiene (ni debe tener) una función de "hacerme admin".
CREATE OR REPLACE FUNCTION public.bloquear_cambio_rol_cliente()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NEW.rol IS DISTINCT FROM COALESCE(OLD.rol, 'cliente') THEN
    RAISE EXCEPTION 'No tienes permiso para cambiar el campo rol.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bloquear_cambio_rol ON public.usuarios;
CREATE TRIGGER trg_bloquear_cambio_rol
  BEFORE INSERT OR UPDATE ON public.usuarios
  FOR EACH ROW EXECUTE FUNCTION public.bloquear_cambio_rol_cliente();


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  2. TOTAL DEL PEDIDO CALCULADO EN EL SERVIDOR (no confiar en el cliente) ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- Mismo criterio que PedidoLocalModel.total en Dart: tamaño + frutas +
-- extras. El sabor NO se suma (así lo hace también el cliente). Se usa
-- COALESCE entre `tamanos` y `tamanos_yogur` porque en este proyecto
-- conviven ambos catálogos de tamaño según el flujo (personalizado vs.
-- tradicional).
CREATE OR REPLACE FUNCTION public.calcular_total_pedido(
  p_tamano_id UUID,
  p_pedido_id UUID
) RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tamano NUMERIC := 0;
  v_frutas NUMERIC := 0;
  v_extras NUMERIC := 0;
BEGIN
  SELECT COALESCE(
    (SELECT precio_base FROM tamanos WHERE id = p_tamano_id),
    (SELECT precio FROM tamanos_yogur WHERE id = p_tamano_id),
    0
  ) INTO v_tamano;

  IF p_pedido_id IS NOT NULL THEN
    SELECT COALESCE(SUM(f.precio_adicional), 0) INTO v_frutas
      FROM pedido_frutas pf JOIN frutas f ON f.id = pf.fruta_id
      WHERE pf.pedido_id = p_pedido_id;

    SELECT COALESCE(SUM(e.precio_adicional), 0) INTO v_extras
      FROM pedido_extras pe JOIN extras e ON e.id = pe.extra_id
      WHERE pe.pedido_id = p_pedido_id;
  END IF;

  RETURN v_tamano + v_frutas + v_extras;
END;
$$;

-- BEFORE INSERT/UPDATE en pedidos: sobreescribe NEW.total con el valor real,
-- sin importar qué haya mandado el cliente en el payload.
--
-- Nota: createPedidoFromCartItem() (checkout de carrito/prediseñados) puede
-- insertar pedidos SIN tamano_id (columna nullable en ese flujo). Para esos
-- casos no tenemos todavía una tabla que ligue el pedido a qué prediseñado
-- se pidió, así que no podemos recalcular su precio real en el servidor sin
-- rediseñar ese flujo — por ahora solo protegemos el total cuando sí hay
-- tamano_id (el flujo principal de personalizado, que es el que se probó
-- vulnerable). Queda documentado como pendiente si se quiere blindar también
-- el checkout de carrito.
CREATE OR REPLACE FUNCTION public.trg_fijar_total_pedido()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.tamano_id IS NOT NULL THEN
    NEW.total := public.calcular_total_pedido(NEW.tamano_id, NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fijar_total_pedido ON public.pedidos;
CREATE TRIGGER trg_fijar_total_pedido
  BEFORE INSERT OR UPDATE ON public.pedidos
  FOR EACH ROW EXECUTE FUNCTION public.trg_fijar_total_pedido();

-- Cuando el checkout agrega/quita frutas o extras DESPUÉS de crear el
-- pedido (necesita el pedido_id ya generado), "tocamos" la fila del pedido
-- para que el trigger de arriba recalcule el total con los datos reales.
CREATE OR REPLACE FUNCTION public.trg_recalcular_total_desde_detalle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pedido_id UUID;
BEGIN
  v_pedido_id := COALESCE(NEW.pedido_id, OLD.pedido_id);
  UPDATE public.pedidos SET updated_at = updated_at WHERE id = v_pedido_id;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_recalcular_total_frutas ON public.pedido_frutas;
CREATE TRIGGER trg_recalcular_total_frutas
  AFTER INSERT OR UPDATE OR DELETE ON public.pedido_frutas
  FOR EACH ROW EXECUTE FUNCTION public.trg_recalcular_total_desde_detalle();

DROP TRIGGER IF EXISTS trg_recalcular_total_extras ON public.pedido_extras;
CREATE TRIGGER trg_recalcular_total_extras
  AFTER INSERT OR UPDATE OR DELETE ON public.pedido_extras
  FOR EACH ROW EXECUTE FUNCTION public.trg_recalcular_total_desde_detalle();


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  3. PROTEGER LA TRANSICIÓN DE ESTADO DEL PEDIDO                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- El cliente solo puede: (a) crear su pedido en 'Recibido', y (b) cancelarlo
-- mientras siga en 'Recibido' (HU_23, cancelarPedido() en el repositorio).
-- Cualquier otro cambio de estado (En preparación, En camino, Entregado)
-- solo lo puede hacer el administrador — igual que ya hace la app.
DROP POLICY IF EXISTS "pedidos_insert_own" ON public.pedidos;
CREATE POLICY "pedidos_insert_own" ON public.pedidos FOR INSERT
  WITH CHECK (cliente_id = auth.uid() AND estado = 'Recibido');

DROP POLICY IF EXISTS "pedidos_update"     ON public.pedidos;
DROP POLICY IF EXISTS "pedidos_update_own" ON public.pedidos;
CREATE POLICY "pedidos_update" ON public.pedidos FOR UPDATE
  USING (
    cliente_id = auth.uid()
    OR public.is_admin()
  )
  WITH CHECK (
    public.is_admin()
    OR (
      cliente_id = auth.uid()
      AND estado = 'Cancelado'
      AND (SELECT p2.estado FROM public.pedidos p2 WHERE p2.id = pedidos.id) = 'Recibido'
    )
  );

-- ── Verificación ─────────────────────────────────────────────────────────
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename IN ('usuarios', 'pedidos')
ORDER BY tablename, policyname;
