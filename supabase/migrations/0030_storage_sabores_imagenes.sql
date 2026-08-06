-- Migration 0030: Storage bucket para fotos de sabores (yogures).
--
-- Los usuarios ven las fotos de los yogures en Home, detalle de producto
-- y personalización (campo `imagen_url` de la tabla `sabores`), pero no
-- había ninguna forma de subir esas fotos desde la app — había que
-- escribir la URL a mano directo en Supabase. Este bucket permite que el
-- admin suba la imagen desde el panel y se guarde la URL pública sola.

-- 1. Crear el bucket (público: cualquiera puede LEER las imágenes, que es
--    justo lo que necesitamos para mostrarlas en la app).
INSERT INTO storage.buckets (id, name, public)
VALUES ('sabores', 'sabores', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Políticas sobre storage.objects, filtradas por bucket_id = 'sabores'.
DROP POLICY IF EXISTS "sabores_imagenes_select_public" ON storage.objects;
DROP POLICY IF EXISTS "sabores_imagenes_insert_admin" ON storage.objects;
DROP POLICY IF EXISTS "sabores_imagenes_update_admin" ON storage.objects;
DROP POLICY IF EXISTS "sabores_imagenes_delete_admin" ON storage.objects;

-- Lectura pública (necesario para que CachedNetworkImage cargue la foto
-- sin que el usuario tenga que estar autenticado).
CREATE POLICY "sabores_imagenes_select_public"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'sabores');

-- Solo el admin puede subir/editar/borrar fotos.
CREATE POLICY "sabores_imagenes_insert_admin"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'sabores'
    AND EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );

CREATE POLICY "sabores_imagenes_update_admin"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'sabores'
    AND EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );

CREATE POLICY "sabores_imagenes_delete_admin"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'sabores'
    AND EXISTS (SELECT 1 FROM usuarios WHERE id = auth.uid() AND rol = 'administrador')
  );
