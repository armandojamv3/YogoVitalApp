-- Migration 0049: tokens de dispositivo para notificaciones push.
--
-- ── POR QUÉ ─────────────────────────────────────────────────────────────
-- Las notificaciones que se guardan en la tabla `notificaciones` (0046,
-- 0047) solo se ven cuando el usuario abre la app. Para que al
-- administrador le suene el teléfono con la app cerrada hace falta push, y
-- para eso hay que saber a qué dispositivo enviar.
--
-- FCM identifica cada instalación con un token. Cambia cuando se
-- reinstala la app, se borran los datos o Firebase decide rotarlo, así que
-- la app lo vuelve a guardar cada vez que arranca y cada vez que FCM avisa
-- de un cambio.
--
-- Un mismo usuario puede tener varios dispositivos (el celular y la tablet
-- del mostrador), de ahí que la clave sea el token y no el usuario.
--
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query → Run
-- Es idempotente.

CREATE TABLE IF NOT EXISTS public.dispositivos (
  token       TEXT PRIMARY KEY,
  usuario_id  UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
  plataforma  TEXT NOT NULL DEFAULT 'android',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.dispositivos
  DROP CONSTRAINT IF EXISTS dispositivos_plataforma_valida;
ALTER TABLE public.dispositivos
  ADD CONSTRAINT dispositivos_plataforma_valida
  CHECK (plataforma IN ('android', 'ios', 'web'));

CREATE INDEX IF NOT EXISTS idx_dispositivos_usuario
  ON public.dispositivos(usuario_id);


-- ── RLS ──────────────────────────────────────────────────────────────────
-- Cada quien administra solo sus propios dispositivos. Nadie puede listar
-- los tokens de otro: con un token ajeno se le podrían mandar
-- notificaciones falsas a esa persona.
--
-- La Edge Function no pasa por aquí — usa la service_role key, que se salta
-- RLS.

ALTER TABLE public.dispositivos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dispositivos_select_own" ON public.dispositivos;
CREATE POLICY "dispositivos_select_own" ON public.dispositivos
  FOR SELECT USING (usuario_id = auth.uid());

DROP POLICY IF EXISTS "dispositivos_insert_own" ON public.dispositivos;
CREATE POLICY "dispositivos_insert_own" ON public.dispositivos
  FOR INSERT WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS "dispositivos_update_own" ON public.dispositivos;
CREATE POLICY "dispositivos_update_own" ON public.dispositivos
  FOR UPDATE USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

DROP POLICY IF EXISTS "dispositivos_delete_own" ON public.dispositivos;
CREATE POLICY "dispositivos_delete_own" ON public.dispositivos
  FOR DELETE USING (usuario_id = auth.uid());


-- ── Registro del token ───────────────────────────────────────────────────
-- La app llama a esto en cada arranque y cuando FCM rota el token.
--
-- Se hace con una función y no con un upsert directo por un motivo: un
-- token puede haber pertenecido antes a OTRA cuenta, si dos personas usan
-- el mismo teléfono. En ese caso hay que reasignarlo, no dejarlo apuntando
-- al usuario anterior — que seguiría recibiendo notificaciones ajenas.
CREATE OR REPLACE FUNCTION public.registrar_dispositivo(
  p_token      TEXT,
  p_plataforma TEXT DEFAULT 'android'
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Usuario no autenticado';
  END IF;

  IF p_token IS NULL OR length(trim(p_token)) = 0 THEN
    RAISE EXCEPTION 'Token vacío';
  END IF;

  IF p_plataforma NOT IN ('android', 'ios', 'web') THEN
    RAISE EXCEPTION 'Plataforma inválida: %', p_plataforma;
  END IF;

  INSERT INTO dispositivos (token, usuario_id, plataforma)
  VALUES (p_token, v_uid, p_plataforma)
  ON CONFLICT (token) DO UPDATE
    SET usuario_id = EXCLUDED.usuario_id,
        plataforma = EXCLUDED.plataforma,
        updated_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_dispositivo(TEXT, TEXT)
  TO authenticated;


-- ── Baja del dispositivo al cerrar sesión ────────────────────────────────
-- Si no se borra el token, quien inicie sesión después en ese teléfono
-- seguiría recibiendo las notificaciones del usuario anterior hasta que la
-- app volviera a registrarlo.
CREATE OR REPLACE FUNCTION public.eliminar_dispositivo(p_token TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;  -- sesión ya cerrada: nada que hacer
  END IF;
  DELETE FROM dispositivos
   WHERE token = p_token AND usuario_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.eliminar_dispositivo(TEXT) TO authenticated;


-- ── Verificación ─────────────────────────────────────────────────────────

-- 1. La tabla y sus políticas
SELECT policyname, cmd FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'dispositivos'
ORDER BY policyname;

-- 2. Dispositivos registrados (tras abrir la app en el emulador)
SELECT d.token, d.plataforma, d.updated_at, u.nombre, u.rol
FROM dispositivos d
JOIN usuarios u ON u.id = d.usuario_id
ORDER BY d.updated_at DESC;
