# Revisión del proyecto — 6 de agosto de 2026

Revisión de estado, calidad y seguridad de YogoVitalApp.

**Alcance y límites.** Está hecha leyendo el código y las migraciones del
repositorio. No incluye ejecutar la app ni consultar la base de datos real:
lo segundo importa, porque este proyecto ya ha tenido cuatro casos de
desfase entre lo que dice el repo y lo que hay en Supabase (migraciones
0026, 0031, 0037 y 0044). Al final hay consultas para comprobarlo.

Tampoco es una auditoría de seguridad profesional. Es una revisión de código
por alguien que conoce el proyecto.

---

## Resumen

El proyecto está mejor de lo que suele estar un trabajo de este tamaño hecho
por una persona. La parte de seguridad —que es donde más se falla— está
razonablemente construida: 16 tablas con RLS, escalada de privilegios
bloqueada, y las operaciones críticas movidas al servidor.

Lo que falta no son parches, son dos ausencias estructurales: **no hay
tests** y **casi ninguna consulta tiene límite**. Ninguna de las dos duele
hoy; las dos duelen cuando haya usuarios.

| | |
|---|---|
| Líneas de Dart | 21.435 en 91 archivos |
| Tests | **0** |
| Bloques `catch` | 118, de los cuales **28 vacíos** |
| Consultas con límite | 4 de 42 |
| Migraciones | 47 |
| Tablas con RLS | 16 |

---

## Seguridad

### 🔴 Cualquiera puede averiguar si un correo está registrado

`check_email_exists` está concedida al rol `anon`:

```sql
GRANT EXECUTE ON FUNCTION public.check_email_exists(TEXT) TO anon;
```

La usa el registro para avisar "Correo ya registrado" mientras escribes.
Pero la anon key está dentro del binario de la app y es pública por diseño,
así que cualquiera puede llamar esa función en bucle con una lista de
correos y saber cuáles tienen cuenta.

Eso filtra **quién es cliente del negocio**. Y para quien prepare un ataque
de credenciales, reduce la lista de objetivos a los que existen de verdad.

Opciones, de menos a más trabajo:

1. Quitar el `GRANT` a `anon` y dejarlo solo para `authenticated`. La
   validación en vivo del registro se pierde, pero `signUp` ya devuelve
   error si el correo existe.
2. Dejarla y limitar el ritmo de llamadas (Authentication → Rate Limits).
3. Aceptar el riesgo. Es lo que hacen muchas apps, a cambio de mejor
   experiencia de registro. Pero conviene que sea una decisión, no un
   descuido.

### 🟡 Contraseña de Postgres en el repositorio

`docker-compose.yml`, commiteado y ya subido a GitHub:

```yaml
POSTGRES_PASSWORD: Jamv3123
PGADMIN_DEFAULT_PASSWORD: admin
```

Esa base de Docker es local y no la usa la app —que va contra Supabase—,
así que el daño directo es bajo. **El riesgo real es otro: si esa contraseña
se reutiliza en algún otro sitio, ya está publicada.** Si es el caso,
cámbiala en los demás sitios; borrarla del repo no basta, queda en el
historial de git.

Y si el repositorio es público, revísalo ahora.

Lo correcto es un `.env` fuera de git:

```yaml
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

### 🟡 Un cliente puede añadir ingredientes a su pedido después de crearlo

Las tablas `pedido_frutas` y `pedido_extras` conservan políticas de INSERT
para el cliente (migración 0025). Con el total ya fijado al crear el pedido
(0043), añadir una fruta después **no abarata nada** — pero regala un
ingrediente que no se cobró.

No lo toqué en la 0043 a propósito: las políticas de esas dos tablas están
repartidas entre las migraciones 0018, 0022, 0025 y `SUPABASE_SETUP.sql`,
con nombres que se pisan, y no se puede saber desde el repo cuáles siguen
vivas. Tocarlas a ciegas arriesga romper la lectura del detalle del pedido.

Antes de arreglarlo hay que mirar qué existe de verdad (consulta 2 al final).

### 🟡 Nada impide cien pedidos en un minuto

No hay límite de pedidos por usuario ni por ventana de tiempo. No hace falta
mala intención: un doble toque en "Confirmar" con la red lenta crea dos
pedidos idénticos.

Lo mínimo sería rechazar en `crear_pedido()` un pedido idéntico al anterior
del mismo cliente dentro de, por ejemplo, un minuto.

### 🟡 Toda la seguridad descansa en RLS

La URL y la anon key están en `main.dart`. Es correcto —la anon key está
pensada para ser pública— pero tiene una consecuencia: **si una política RLS
está mal, no hay una segunda barrera.** Cualquiera puede sacar esa key del
APK y hablar directo con tu base.

Por eso importa tanto verificar el estado real de las políticas.

### 🟢 Lo que está bien hecho

Vale la pena decirlo, porque es donde más suele fallar este tipo de
proyectos:

- **16 tablas con RLS habilitado.** No quedó ninguna suelta.
- **`usuarios_select_own`**: un cliente solo puede leer su propia fila. No
  puede listar los usuarios ni ver correos ajenos.
- **`trg_bloquear_cambio_rol`** (0035) impide que alguien se ascienda a
  administrador con un UPDATE desde la API. Es el agujero clásico de estos
  proyectos y aquí está tapado.
- **`is_admin()` como SECURITY DEFINER**, que además evitó la recursión
  infinita de políticas que costó varias migraciones.
- **Crear y cancelar pedidos** son ahora funciones del servidor, atómicas, y
  el cliente ya no puede escribir en `pedidos`.
- **Storage**: lectura pública, escritura solo para administradores.
- **La Edge Function valida el JWT de quien llama** y comprueba que sea el
  propio cliente o un admin. Un comentario documenta que antes no lo hacía y
  se podía sondear usuarios: alguien detectó y arregló una vulnerabilidad
  real ahí.
- **`tamanos_yogur` es de solo lectura** desde la API: los precios de los
  tamaños no se pueden alterar desde la app.

---

## Calidad del código

### 🔴 Cero tests

21.435 líneas sin una sola prueba. `flutter_test` está en las dependencias,
pero la carpeta `test/` no existe.

La consecuencia se vio hoy: la migración 0041 rompió el cálculo del total de
los pedidos y **nadie se enteró durante una semana**. Un test que creara un
pedido con frutas y comprobara el total lo habría cazado en el momento.

No hace falta cubrirlo todo. Con probar el cálculo de precios y las
transiciones de estado ya se cubre lo que de verdad puede costar dinero.

### 🟡 28 bloques `catch` que se tragan el error

De 118 bloques `catch`, 28 son `catch (_)` sin registrar nada.

Esto ya costó tiempo hoy dos veces: el error de carga de sabores fue
imposible de diagnosticar hasta añadir un `debugPrint`, y el fallo del
cambio de estado que motivó la migración 0041 era invisible por lo mismo
—hay un comentario en el propio código que lo dice.

No hace falta mostrárselos al usuario. Basta `debugPrint` antes de
silenciarlos.

### 🟡 Solo 4 de 42 consultas tienen límite

El historial del cliente ya está paginado. Faltan las demás, y una en
concreto preocupa:

`streamTodosPedidos()` trae **los pedidos de todos los clientes, sin
límite**, y Realtime lo reemite entero en cada cambio. Con 2.000 pedidos,
cada pedido nuevo obliga a descargar los 2.000 otra vez, a cada admin
conectado. Hay filtro de fechas, pero por defecto no se aplica ninguno.

Conviene resolverlo antes de tener volumen.

### 🟡 Lógica duplicada

`PedidoSupabaseRepository.getHistorial()` y `HistorialRepository.getPedidos()`
hacen lo mismo. Solo el segundo se usa y solo el segundo está paginado. El
primero es código muerto o una trampa para el próximo que lo llame.

### 🟡 Desfase entre el repositorio y la base real

Cuatro migraciones existen únicamente para reconciliar cosas creadas a mano
en el dashboard: la 0026, la 0031, la 0037 y la 0044. La última fue hoy,
cuando aparecieron `tipo`, `costo_envio` y tres CHECK constraints que no
estaban en ninguna parte del repo.

Cada vez cuesta lo mismo: escribir código contra un esquema que no es el
real, y descubrirlo cuando algo revienta.

La regla que lo corta: **ningún cambio de esquema se hace en el dashboard.**
Se escribe una migración, se corre desde el editor SQL, y queda en git.

### 🟢 Lo que está bien

- **Arquitectura por capas clara** (`core` / `data` / `presentation`), y
  respetada.
- **Las migraciones están extraordinariamente bien documentadas.** Explican
  el síntoma, la causa raíz y por qué se eligió esa solución. Es mejor
  documentación de la que tiene la mayoría del software comercial.
- **`analysis_options.yaml` activo** y el proyecto analiza limpio: 0 errores,
  6 avisos menores.

---

## Funcionalidad pendiente de verificar

Nada de lo siguiente se ha probado nunca en un dispositivo:

- **Deep links y correos de autenticación** (migraciones de hoy). No se
  pueden probar en Windows con un iPhone; hace falta un emulador Android o
  un Mac.
- **Notificaciones al admin** de pedidos nuevos y cancelaciones (0046, 0047).
- **El error de carga de sabores** que apareció una vez y no se explicó. Hay
  un `debugPrint` esperándolo.

## Funcionalidad que falta

- **El admin no puede cambiar los precios de los tamaños** desde la app.
  `tamanos_yogur` es de solo lectura vía API: hay que entrar por SQL.
- **No hay push real.** Con la app cerrada, el administrador no se entera de
  nada. Requiere Firebase.

---

## Qué haría, por orden

1. **Decidir sobre `check_email_exists`.** Es el único hallazgo de seguridad
   que expone datos hoy.
2. **Comprobar si `Jamv3123` se usa en otro sitio.** Si sí, cambiarla ahí.
3. **Correr las consultas de verificación** de abajo y comparar con lo que
   dice el repo.
4. **Escribir cuatro tests**: total de un pedido personalizado con frutas y
   extras, total de un prediseñado con tamaño, transición de estado
   permitida, transición prohibida. Son las cuatro cosas que pueden costar
   dinero.
5. **Poner límite a `streamTodosPedidos()`.**
6. **`debugPrint` en los 28 `catch` vacíos.**

Lo demás puede esperar.

---

## Consultas de verificación

Para correr en Supabase → SQL Editor, una a la vez. Sirven para comprobar
que la base real coincide con lo que dice el repositorio.

```sql
-- 1. Tablas SIN RLS habilitado. Debería salir vacío.
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT IN (
    SELECT c.relname FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relrowsecurity
  )
ORDER BY tablename;
```

```sql
-- 2. Políticas reales de pedido_frutas y pedido_extras.
--    Necesario antes de decidir si se cierra la escritura del cliente.
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('pedido_frutas', 'pedido_extras')
ORDER BY tablename, policyname;
```

```sql
-- 3. Tablas con RLS habilitado pero SIN ninguna política.
--    Son invisibles para todo el mundo: si alguna debería leerse desde la
--    app, está rota.
SELECT c.relname AS tabla
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relrowsecurity
  AND NOT EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname = 'public' AND p.tablename = c.relname
  )
ORDER BY 1;
```

```sql
-- 4. Todas las funciones SECURITY DEFINER. Cada una se salta RLS, así que
--    cada una tiene que validar por su cuenta quién la llama.
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS argumentos,
       p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prosecdef
ORDER BY p.proname;
```

```sql
-- 5. Quién es administrador. Debería ser exactamente quien esperas.
SELECT id, nombre, correo, rol FROM usuarios WHERE rol = 'administrador';
```

```sql
-- 6. Columnas de `pedidos` que no aparecen en ninguna migración del repo.
--    Compara esta lista con lo que tengas en supabase/migrations/.
SELECT ordinal_position, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'pedidos'
ORDER BY ordinal_position;
```
