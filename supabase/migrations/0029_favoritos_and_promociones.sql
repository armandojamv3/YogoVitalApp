-- Migration 0029: Favoritos (cliente) + Promociones (admin -> cliente).
--
-- Favoritos: el cliente marca sabores como favoritos con un corazón.
-- Promociones: el admin publica anuncios/promos con vigencia; el cliente
-- ve solo las que están activas y dentro de su rango de fechas. Es
-- informativo (no aplica descuentos automáticos al total del pedido).

-- ── 1. Tabla favoritos ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.favoritos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id  UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  sabor_id    UUID NOT NULL REFERENCES public.sabores(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (cliente_id, sabor_id)
);

ALTER TABLE public.favoritos ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE pol TEXT;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'favoritos'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.favoritos', pol);
  END LOOP;
END $$;

CREATE POLICY "favoritos_select_own"
  ON public.favoritos FOR SELECT
  USING (cliente_id = auth.uid());

CREATE POLICY "favoritos_insert_own"
  ON public.favoritos FOR INSERT
  WITH CHECK (cliente_id = auth.uid());

CREATE POLICY "favoritos_delete_own"
  ON public.favoritos FOR DELETE
  USING (cliente_id = auth.uid());

-- ── 2. Tabla promociones ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.promociones (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  titulo        TEXT NOT NULL,
  descripcion   TEXT NOT NULL,
  fecha_inicio  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  fecha_fin     TIMESTAMPTZ,
  activa        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.promociones ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE pol TEXT;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'promociones'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.promociones', pol);
  END LOOP;
END $$;

-- Cualquiera autenticado puede leer (el filtro de "vigente" se hace en
-- el cliente Dart: activa = true y dentro del rango de fechas).
CREATE POLICY "promociones_select_all"
  ON public.promociones FOR SELECT
  USING (true);

-- Solo el admin puede crear/editar/eliminar.
CREATE POLICY "promociones_insert_admin"
  ON public.promociones FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );

CREATE POLICY "promociones_update_admin"
  ON public.promociones FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );

CREATE POLICY "promociones_delete_admin"
  ON public.promociones FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );
