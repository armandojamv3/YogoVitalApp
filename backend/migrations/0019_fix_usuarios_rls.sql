-- Migration 0019: Fix definitivo para recursión infinita en RLS de usuarios
-- Error: PostgrestException(code: 42P17) "infinite recursion detected in
--        policy for relation usuarios"
--
-- Causa raíz: alguna política en public.usuarios hace un SELECT a
-- public.usuarios dentro de su USING() / WITH CHECK(), creando un
-- bucle infinito. Puede ocurrir también si la política de public.pedidos
-- referencia a public.usuarios (la cual a su vez tiene RLS recursivo).
--
-- Este script es idempotente: se puede ejecutar varias veces sin daño.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  1. TABLA usuarios — eliminar TODO y recrear políticas mínimas          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
DO $$
DECLARE pol TEXT;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'usuarios'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.usuarios', pol);
  END LOOP;
END $$;

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

-- Cada usuario solo ve su propia fila (sin cruzar a otras tablas)
CREATE POLICY "usuarios_select_own"
  ON public.usuarios FOR SELECT
  USING (id = auth.uid());

-- Cada usuario actualiza solo sus propios datos
CREATE POLICY "usuarios_update_own"
  ON public.usuarios FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Registro: el usuario puede insertar su propia fila
CREATE POLICY "usuarios_insert_own"
  ON public.usuarios FOR INSERT
  WITH CHECK (id = auth.uid());

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  2. TABLA pedidos — limpiar políticas que pudieran cruzar a usuarios    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
DO $$
DECLARE pol TEXT;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pedidos'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.pedidos', pol);
  END LOOP;
END $$;

ALTER TABLE public.pedidos ENABLE ROW LEVEL SECURITY;

-- Clientes ven solo sus propios pedidos
CREATE POLICY "pedidos_select_own"
  ON public.pedidos FOR SELECT
  USING (cliente_id = auth.uid());

-- Clientes crean pedidos a su nombre
CREATE POLICY "pedidos_insert_own"
  ON public.pedidos FOR INSERT
  WITH CHECK (cliente_id = auth.uid());

-- Clientes pueden actualizar sus pedidos (ej. cancelar)
CREATE POLICY "pedidos_update_own"
  ON public.pedidos FOR UPDATE
  USING (cliente_id = auth.uid());

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  3. Eliminar funciones helper antiguas (si existen)                     ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS public.is_admin();
DROP FUNCTION IF EXISTS _drop_all_policies(TEXT);

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  4. Verificación — muestra las políticas activas                        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('usuarios', 'pedidos')
ORDER BY tablename, policyname;
