-- ============================================================
-- YOGO VITAL — SUPABASE COMPLETE SETUP
-- ============================================================
-- Pega TODO este archivo en:
--   Supabase Dashboard → SQL Editor → "New query" → Run
--
-- El script es idempotente (puedes ejecutarlo varias veces).
-- Crea todas las tablas, funciones, triggers, RLS y datos de prueba.
-- ============================================================


-- ══════════════════════════════════════════════════════════════
-- PASO 1 — TABLA USUARIOS (vinculada a auth.users)
-- ══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.usuarios (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre     TEXT NOT NULL DEFAULT '',
  correo     TEXT NOT NULL DEFAULT '',
  telefono   TEXT,
  rol        TEXT NOT NULL DEFAULT 'cliente',
  fcm_token  TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);


-- ══════════════════════════════════════════════════════════════
-- PASO 2 — TRIGGER: crea un registro en usuarios al registrarse
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.usuarios (id, nombre, correo, telefono, rol)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nombre',   ''),
    COALESCE(NEW.email,                            ''),
    COALESCE(NEW.raw_user_meta_data->>'telefono', ''),
    'cliente'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ══════════════════════════════════════════════════════════════
-- PASO 3 — FUNCIÓN check_email_exists (registro: verificar duplicado)
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.check_email_exists(email_to_check TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users
    WHERE email = lower(trim(email_to_check))
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_email_exists(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.check_email_exists(TEXT) TO authenticated;


-- ══════════════════════════════════════════════════════════════
-- PASO 4 — CATÁLOGO: sabores, tamaños, frutas, extras, prediseñados
-- ══════════════════════════════════════════════════════════════

-- Sabores
CREATE TABLE IF NOT EXISTS public.sabores (
  id                    UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre                TEXT    NOT NULL UNIQUE,
  descripcion           TEXT    NOT NULL DEFAULT '',
  precio_base           NUMERIC(10,2) NOT NULL CHECK (precio_base > 0),
  imagen_url            TEXT,
  -- NULL = todavía nadie lo ha calificado (ver migración 0050).
  calificacion_promedio NUMERIC(3,2),
  activo                BOOLEAN NOT NULL DEFAULT true,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tamaños (para pedidos personalizados)
CREATE TABLE IF NOT EXISTS public.tamanos (
  id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT    NOT NULL UNIQUE,
  precio_base NUMERIC(10,2) NOT NULL CHECK (precio_base >= 0)
);

INSERT INTO public.tamanos (nombre, precio_base) VALUES
  ('Personal', 5000),
  ('½ Litro',  8000),
  ('1 Litro',  14000),
  ('2 Litros', 25000)
ON CONFLICT (nombre) DO UPDATE SET precio_base = EXCLUDED.precio_base;

-- Tamaños Yogur (para Yogur Tradicional)
CREATE TABLE IF NOT EXISTS public.tamanos_yogur (
  id     UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT    NOT NULL UNIQUE,
  precio NUMERIC(10,2) NOT NULL CHECK (precio >= 0)
);

INSERT INTO public.tamanos_yogur (nombre, precio) VALUES
  ('Personal', 5000),
  ('½ Litro',  8000),
  ('1 Litro',  14000),
  ('2 Litros', 25000)
ON CONFLICT (nombre) DO UPDATE SET precio = EXCLUDED.precio;

-- Frutas
CREATE TABLE IF NOT EXISTS public.frutas (
  id               UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre           TEXT    NOT NULL UNIQUE,
  precio_adicional NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (precio_adicional >= 0),
  disponible       BOOLEAN NOT NULL DEFAULT true,
  imagen_url       TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Extras
CREATE TABLE IF NOT EXISTS public.extras (
  id               UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre           TEXT    NOT NULL UNIQUE,
  precio_adicional NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (precio_adicional >= 0),
  disponible       BOOLEAN NOT NULL DEFAULT true,
  imagen_url       TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Prediseñados
CREATE TABLE IF NOT EXISTS public.predisenhados (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre       TEXT    NOT NULL,
  descripcion  TEXT    NOT NULL DEFAULT '',
  ingredientes JSONB   NOT NULL DEFAULT '[]',
  precio_total NUMERIC(10,2) NOT NULL DEFAULT 0,
  imagen_url   TEXT,
  activo       BOOLEAN NOT NULL DEFAULT true,
  es_popular   BOOLEAN NOT NULL DEFAULT false,
  es_nuevo     BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- ══════════════════════════════════════════════════════════════
-- PASO 5 — PEDIDOS y tablas relacionadas
-- ══════════════════════════════════════════════════════════════

-- Direcciones
CREATE TABLE IF NOT EXISTS public.direcciones (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id   UUID    NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  direccion    TEXT    NOT NULL,
  barrio       TEXT    NOT NULL DEFAULT '',
  telefono     TEXT    NOT NULL DEFAULT '',
  es_principal BOOLEAN NOT NULL DEFAULT false,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Pedidos
CREATE TABLE IF NOT EXISTS public.pedidos (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  cliente_id   UUID    NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
  direccion_id UUID    REFERENCES public.direcciones(id) ON DELETE SET NULL,
  tamano_id    UUID    NOT NULL REFERENCES public.tamanos(id),
  sabor_id     UUID    NOT NULL REFERENCES public.sabores(id),
  estado       TEXT    NOT NULL DEFAULT 'Recibido',
  total        NUMERIC(10,2) NOT NULL CHECK (total >= 0),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pedidos_cliente ON pedidos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado  ON pedidos(estado);
CREATE INDEX IF NOT EXISTS idx_pedidos_fecha   ON pedidos(created_at DESC);

-- Pedido_Frutas (junction)
CREATE TABLE IF NOT EXISTS public.pedido_frutas (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id UUID NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
  fruta_id  UUID NOT NULL REFERENCES public.frutas(id),
  UNIQUE (pedido_id, fruta_id)
);

-- Pedido_Extras (junction)
CREATE TABLE IF NOT EXISTS public.pedido_extras (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id UUID NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
  extra_id  UUID NOT NULL REFERENCES public.extras(id),
  UNIQUE (pedido_id, extra_id)
);

-- Calificaciones
CREATE TABLE IF NOT EXISTS public.calificaciones (
  id         UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id  UUID    NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
  cliente_id UUID    NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  estrellas  SMALLINT NOT NULL CHECK (estrellas BETWEEN 1 AND 5),
  comentario TEXT    CHECK (char_length(comentario) <= 200),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (pedido_id)
);

CREATE INDEX IF NOT EXISTS idx_calificaciones_pedido  ON calificaciones(pedido_id);
CREATE INDEX IF NOT EXISTS idx_calificaciones_cliente ON calificaciones(cliente_id);

-- Historial de estados
CREATE TABLE IF NOT EXISTS public.historial_estados (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id       UUID NOT NULL REFERENCES public.pedidos(id) ON DELETE CASCADE,
  estado_anterior TEXT,
  estado_nuevo    TEXT NOT NULL,
  fecha_cambio    TIMESTAMPTZ NOT NULL DEFAULT now(),
  admin_id        UUID REFERENCES public.usuarios(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_historial_pedido ON historial_estados(pedido_id);


-- ══════════════════════════════════════════════════════════════
-- PASO 6 — ROW LEVEL SECURITY (RLS)
-- ══════════════════════════════════════════════════════════════

-- ── usuarios ──────────────────────────────────────────────────────────────
ALTER TABLE usuarios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "usuarios_select_own" ON usuarios;
DROP POLICY IF EXISTS "usuarios_update_own" ON usuarios;
DROP POLICY IF EXISTS "admin_select_usuarios" ON usuarios;

CREATE POLICY "usuarios_select_own" ON usuarios FOR SELECT
  USING (
    id = auth.uid()
    OR EXISTS (SELECT 1 FROM usuarios u WHERE u.id = auth.uid() AND u.rol = 'administrador')
  );
CREATE POLICY "usuarios_update_own" ON usuarios FOR UPDATE
  USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- ── sabores ───────────────────────────────────────────────────────────────
ALTER TABLE sabores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin_all_sabores"      ON sabores;
DROP POLICY IF EXISTS "cliente_select_sabores" ON sabores;

CREATE POLICY "admin_all_sabores" ON sabores
  USING (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'))
  WITH CHECK (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'));
CREATE POLICY "cliente_select_sabores" ON sabores FOR SELECT
  USING (activo = true
         OR EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'));

-- ── tamanos ───────────────────────────────────────────────────────────────
ALTER TABLE tamanos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tamanos_select_all"  ON tamanos;
DROP POLICY IF EXISTS "admin_all_tamanos"   ON tamanos;
CREATE POLICY "tamanos_select_all" ON tamanos FOR SELECT USING (true);
CREATE POLICY "admin_all_tamanos"  ON tamanos
  USING (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'))
  WITH CHECK (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'));

-- ── tamanos_yogur ─────────────────────────────────────────────────────────
ALTER TABLE tamanos_yogur ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tamanos_yogur_select" ON tamanos_yogur;
CREATE POLICY "tamanos_yogur_select" ON tamanos_yogur FOR SELECT USING (true);

-- ── frutas ────────────────────────────────────────────────────────────────
ALTER TABLE frutas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin_all_frutas"      ON frutas;
DROP POLICY IF EXISTS "cliente_select_frutas" ON frutas;
CREATE POLICY "admin_all_frutas" ON frutas
  USING (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'))
  WITH CHECK (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'));
CREATE POLICY "cliente_select_frutas" ON frutas FOR SELECT
  USING (disponible = true
         OR EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'));

-- ── extras ────────────────────────────────────────────────────────────────
ALTER TABLE extras ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin_all_extras"      ON extras;
DROP POLICY IF EXISTS "cliente_select_extras" ON extras;
CREATE POLICY "admin_all_extras" ON extras
  USING (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'))
  WITH CHECK (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'));
CREATE POLICY "cliente_select_extras" ON extras FOR SELECT
  USING (disponible = true
         OR EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'));

-- ── predisenhados ─────────────────────────────────────────────────────────
ALTER TABLE predisenhados ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "predisenhados_select_activos" ON predisenhados;
DROP POLICY IF EXISTS "admin_all_predisenhados"      ON predisenhados;
CREATE POLICY "predisenhados_select_activos" ON predisenhados FOR SELECT
  USING (activo = true);
CREATE POLICY "admin_all_predisenhados" ON predisenhados
  USING (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'))
  WITH CHECK (EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador'));

-- ── direcciones ───────────────────────────────────────────────────────────
ALTER TABLE direcciones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "direcciones_own" ON direcciones;
CREATE POLICY "direcciones_own" ON direcciones FOR ALL
  USING (cliente_id = auth.uid()) WITH CHECK (cliente_id = auth.uid());

-- ── pedidos ───────────────────────────────────────────────────────────────
ALTER TABLE pedidos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pedidos_select"        ON pedidos;
DROP POLICY IF EXISTS "pedidos_insert_own"    ON pedidos;
DROP POLICY IF EXISTS "pedidos_update"        ON pedidos;

CREATE POLICY "pedidos_select" ON pedidos FOR SELECT
  USING (
    cliente_id = auth.uid()
    OR EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );
CREATE POLICY "pedidos_insert_own" ON pedidos FOR INSERT
  WITH CHECK (cliente_id = auth.uid());
CREATE POLICY "pedidos_update" ON pedidos FOR UPDATE
  USING (
    cliente_id = auth.uid()
    OR EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );

-- ── pedido_frutas ─────────────────────────────────────────────────────────
ALTER TABLE pedido_frutas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pedido_frutas_access" ON pedido_frutas;
CREATE POLICY "pedido_frutas_access" ON pedido_frutas FOR ALL
  USING (
    EXISTS (SELECT 1 FROM pedidos p WHERE p.id = pedido_id AND p.cliente_id = auth.uid())
    OR EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );

-- ── pedido_extras ─────────────────────────────────────────────────────────
ALTER TABLE pedido_extras ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pedido_extras_access" ON pedido_extras;
CREATE POLICY "pedido_extras_access" ON pedido_extras FOR ALL
  USING (
    EXISTS (SELECT 1 FROM pedidos p WHERE p.id = pedido_id AND p.cliente_id = auth.uid())
    OR EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );

-- ── calificaciones ────────────────────────────────────────────────────────
ALTER TABLE calificaciones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "calificaciones_select_all"    ON calificaciones;
DROP POLICY IF EXISTS "calificaciones_insert_owner"  ON calificaciones;
DROP POLICY IF EXISTS "calificaciones_no_update"     ON calificaciones;
DROP POLICY IF EXISTS "calificaciones_no_delete"     ON calificaciones;

CREATE POLICY "calificaciones_select_all" ON calificaciones FOR SELECT USING (true);
CREATE POLICY "calificaciones_insert_owner" ON calificaciones FOR INSERT
  WITH CHECK (
    cliente_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM pedidos
      WHERE pedidos.id = pedido_id
        AND pedidos.cliente_id = auth.uid()
        AND pedidos.estado = 'Entregado'
    )
  );
CREATE POLICY "calificaciones_no_update" ON calificaciones FOR UPDATE USING (false);
CREATE POLICY "calificaciones_no_delete" ON calificaciones FOR DELETE USING (false);

-- ── historial_estados ─────────────────────────────────────────────────────
ALTER TABLE historial_estados ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "historial_select" ON historial_estados;
DROP POLICY IF EXISTS "historial_insert" ON historial_estados;

CREATE POLICY "historial_select" ON historial_estados FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM pedidos p WHERE p.id = pedido_id AND p.cliente_id = auth.uid())
    OR EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );
CREATE POLICY "historial_insert" ON historial_estados FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM pedidos p WHERE p.id = pedido_id AND p.cliente_id = auth.uid())
    OR EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );


-- ══════════════════════════════════════════════════════════════
-- PASO 7 — DATOS DE PRUEBA
-- ══════════════════════════════════════════════════════════════

INSERT INTO public.sabores (nombre, descripcion, precio_base, activo) VALUES
  ('Fresa',      'Yogur de fresa natural, fresco y delicioso',    6500, true),
  ('Mora',       'Intenso sabor a mora silvestre',                6500, true),
  ('Mango',      'Tropical y cremoso sabor a mango',              6500, true),
  ('Vainilla',   'Clásico yogur de vainilla',                     6000, true),
  ('Melocotón',  'Suave y dulce yogur de melocotón',             6500, true),
  ('Maracuyá',   'Sabor exótico y ácido de maracuyá',            7000, true),
  ('Coco',       'Cremoso yogur con esencia de coco',            7000, true),
  ('Chontaduro', 'Sabor único de la región, textura especial',   7500, true)
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO public.frutas (nombre, precio_adicional, disponible) VALUES
  ('Fresas',   1000, true),
  ('Mango',    1000, true),
  ('Banano',    800, true),
  ('Kiwi',     1500, true),
  ('Uvas',     1200, true),
  ('Durazno',  1000, true)
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO public.extras (nombre, precio_adicional, disponible) VALUES
  ('Granola',               800, true),
  ('Chispas de chocolate', 1000, true),
  ('Miel',                  500, true),
  ('Coco rallado',           800, true),
  ('Maní caramelizado',    1000, true)
ON CONFLICT (nombre) DO NOTHING;


-- ══════════════════════════════════════════════════════════════
-- PASO 8 — REALTIME (ejecutar por separado si da error)
-- ══════════════════════════════════════════════════════════════

-- Si el paso anterior falla por permisos, ve a:
-- Supabase Dashboard → Database → Replication
-- y activa Realtime manualmente para: pedidos, frutas, extras
--
-- ALTER PUBLICATION supabase_realtime ADD TABLE pedidos;
-- ALTER PUBLICATION supabase_realtime ADD TABLE frutas;
-- ALTER PUBLICATION supabase_realtime ADD TABLE extras;


-- ══════════════════════════════════════════════════════════════
-- FIN — Yogo Vital database setup completo
-- ══════════════════════════════════════════════════════════════
