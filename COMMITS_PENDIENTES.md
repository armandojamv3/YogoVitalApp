# Plan de commits

Siete commits para los 180 archivos pendientes. Ve uno a uno: pega el bloque,
mira `git status` y sigue con el siguiente.

Estás en la rama `desarrollo`.

**Antes de empezar**, comprueba que compila:

```bash
flutter analyze
```

---

## 1. Trabajo previo: notificaciones, favoritos, promociones y caché offline

Todo lo que ya tenías hecho antes de esta sesión y nunca se commiteó: tres
funcionalidades completas, la caché local de catálogo y dieciséis migraciones
(0027–0042).

Va en un solo commit porque los archivos se cruzan entre sí y separarlos desde
fuera sería inventar una historia que no ocurrió así.

```bash
git add docs/
git add lib/core/models/notificacion.dart
git add lib/core/models/promocion.dart
git add lib/core/models/predisenhado_admin_provider.dart
git add lib/core/models/pedido_local_model.dart
git add lib/core/models/predisenhado_model.dart
git add lib/core/models/sabor_admin_provider.dart
git add lib/core/providers/pedido_provider.dart
git add lib/data/local/
git add lib/data/repositories/favoritos_repository.dart
git add lib/data/repositories/notificaciones_repository.dart
git add lib/data/repositories/predisenhados_admin_repository.dart
git add lib/data/repositories/promociones_repository.dart
git add lib/data/repositories/catalogo_repository.dart
git add lib/data/repositories/personalizacion_repository.dart
git add lib/data/repositories/sabores_admin_repository.dart
git add lib/presentation/pages/favoritos/
git add lib/presentation/pages/notificaciones/
git add lib/presentation/pages/promociones/
git add lib/presentation/pages/admin/admin_predisenhados_page.dart
git add lib/presentation/pages/admin/admin_promociones_page.dart
git add lib/presentation/pages/admin/admin_dashboard_page.dart
git add lib/presentation/pages/admin/admin_sabores_page.dart
git add lib/presentation/pages/account/account_page.dart
git add lib/presentation/pages/cart/cart_page.dart
git add lib/presentation/pages/home/home_page.dart
git add lib/presentation/pages/home/product_detail_page.dart
git add lib/presentation/pages/orders/estado_pedido_supabase_page.dart
git add lib/presentation/pages/orders/resumen_pedido_page.dart
git add lib/presentation/pages/yogurt/categories/personalizado_page.dart
git add lib/presentation/widgets/favorite_button.dart
git add lib/presentation/widgets/notification_bell.dart
git add lib/presentation/widgets/sabor_search_delegate.dart
git add supabase/functions/send-notification/index.ts
git add supabase/migrations/00{27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42}_*.sql
git add pubspec.yaml pubspec.lock
git add linux/ macos/ windows/
git rm --cached lib/presentation/pages/product_detail/product_detail_page.dart
git rm --cached lib/presentation/pages/yogurt/categories/predisenados_page.dart
git rm --cached lib/presentation/pages/yogurt/categories/tradicionales_page.dart

git commit -m "feat: notificaciones, favoritos, promociones y caché offline del catálogo

Trabajo acumulado de julio que nunca llegó a commitearse:

- Notificaciones in-app con campana y contador (migración 0028).
- Favoritos y promociones (0029).
- Panel de admin para prediseñados, con subida de imágenes (0034, 0037-0039).
- Caché local del catálogo en SQLite para que el personalizador funcione
  sin conexión.
- Búsqueda de sabores.
- Migraciones 0027-0042: dulzura del pedido, RLS de admin, storage de
  imágenes, y la serie de correcciones de recursión en las políticas de
  pedidos.

Se eliminan tres pantallas del diseño anterior (product_detail,
predisenados, tradicionales) que ya no se enrutaban desde ningún sitio."
```

---

## 2. El total del pedido se calcula en el servidor

El bug que costaba dinero. La migración 0041 había roto sin querer el
recálculo del total, y desde el 30 de julio los pedidos con frutas o extras
se cobraban solo al precio del tamaño.

```bash
git add supabase/migrations/0043_crear_pedido_rpc.sql
git add lib/data/repositories/pedido_supabase_repository.dart

git commit -m "fix(pedidos): calcular el total en el servidor con una RPC atómica

El total guardado no incluía frutas ni extras desde la migración 0041.

El trigger que fija el total es BEFORE INSERT sobre pedidos, y suma los
ingredientes leyendo pedido_frutas/pedido_extras, que en ese instante
todavía están vacías porque se insertan después. La 0035 lo compensaba
'tocando' la fila del pedido tras insertar los ingredientes, pero la 0041
limitó ese recálculo a los UPDATE que cambian tamano_id — y ese toque no
cambia tamano_id, así que dejó de funcionar.

En vez de reponer el mecanismo de dos triggers encadenados (frágil, y ya
falló una vez), ahora crear_pedido() calcula el total de una sola vez antes
de insertar, leyendo siempre los precios del catálogo.

De paso resuelve otros dos problemas:

- createPedidoFromCartItem() confiaba en el precio que mandaba el cliente:
  se podía insertar un pedido con total 0. Se elimina la política de INSERT
  sobre pedidos, así que la RPC es el único camino posible.
- La creación eran 4 INSERT sueltos sin transacción: si fallaba cualquiera
  de los últimos, quedaba un pedido huérfano sin ingredientes o sin
  historial."
```

---

## 3. Prediseñados: esquema, tipo de pedido y tamaño

Dos migraciones que van juntas: la 0044 documenta columnas que existían solo
en el dashboard, y la 0045 añade el tamaño.

```bash
git add supabase/migrations/0044_tipo_pedido_y_predisenhado_sin_sabor.sql
git add supabase/migrations/0045_predisenhado_con_tamano.sql
git add lib/presentation/pages/cart/cart_checkout_page.dart

git commit -m "fix(pedidos): reconciliar esquema y permitir tamaño en prediseñados

La tabla pedidos tenía dos columnas (tipo, costo_envio) y tres CHECK
constraints que no estaban en ninguna migración del repo: se crearon a mano
en el dashboard. Es el cuarto caso del mismo problema, tras las migraciones
0026, 0031 y 0037. La 0044 los deja versionados.

Por eso fallaba el pedido de prediseñado: crear_pedido() nunca ponía 'tipo',
se quedaba en el default 'personalizado', y el constraint
pedidos_predisenhado_segun_tipo lo rechazaba.

Además, pedidos_sabor_segun_tipo exigía sabor en los pedidos de prediseñado
— una regla del diseño anterior, que contradice a la propia migración 0038,
donde ya se declaró que un prediseñado se define por su lista de
ingredientes y no por un sabor. Se relaja.

La 0045 añade el tamaño, obligatorio, con la misma fórmula que el
personalizado: precio de la receta + precio del tamaño, por cantidad.

Y se corrige un bug que impedía pedir prediseñados desde el carrito: el id
viajaba con el prefijo 'pred_' y se mandaba tal cual como sabor_id, que
Postgres rechazaba por no ser un UUID válido."
```

---

## 4. Pantalla de detalle de prediseñado

```bash
git add lib/presentation/pages/yogurt/predisenhado_detail_page.dart
git add lib/presentation/pages/yogurt/yogurt_page.dart
git add lib/data/repositories/calificacion_supabase_repository.dart
git add lib/data/repositories/historial_repository.dart
git add lib/data/repositories/factura_repository.dart
git add lib/data/repositories/pedidos_admin_repository.dart
git add lib/core/models/pedido_historial.dart
git add lib/core/models/pedido_admin.dart
git add lib/core/models/factura_model.dart
git add lib/core/services/pdf_service.dart
git add lib/presentation/pages/history/
git add lib/presentation/pages/admin/pedido_admin_detalle_screen.dart
git add lib/presentation/pages/orders/factura_screen.dart
git add lib/presentation/widgets/custom_bottom_nav_bar.dart

git commit -m "feat(prediseñados): pantalla de detalle, selección de tamaño y compra directa

La tarjeta de prediseñado no era pulsable: lo único interactivo era el botón
'Seleccionar'. No había forma de leer la descripción completa, ver los
ingredientes ni las opiniones de otros clientes.

- Pantalla de detalle con imagen, descripción, ingredientes, calificaciones
  y selector de tamaño obligatorio.
- 'Pedir ahora': va al checkout con ese ítem sin tocar el carrito.
- Las calificaciones se agrupan por predisenhado_id a través de pedidos, sin
  necesidad de tabla nueva.

Arregla también cómo se veían estos pedidos una vez hechos. El historial, la
factura y el panel de admin consultaban sabores(nombre) y tamanos_yogur, y
un pedido de prediseñado no tiene ninguno de los dos: salía sin nombre. El
admin no podía saber qué preparar.

Y la factura calculaba el subtotal sumando tamaño + frutas + extras, lo que
daba 0 en un prediseñado y también en cualquier pedido de carrito con sabor
suelto — esos mostraban como total solo el costo de envío. Ahora manda
pedidos.total, que es lo que de verdad se cobró.

La barra inferior de navegación tenía altura fija de 60 px y el contenido
quedaba pegado al borde; además solo el icono respondía al toque, no el
hueco entre icono y etiqueta."
```

---

## 5. Carrito persistente

```bash
git add lib/core/models/cart_model.dart

git commit -m "feat(carrito): guardar el carrito entre sesiones

El carrito vivía solo en memoria: se perdía al cerrar la app o al recargar
la página. Ahora se respalda en la base local (SQLite), que hasta ahora solo
guardaba el catálogo.

Se guarda por cliente_id y se borra al cerrar sesión, para que dos cuentas
en el mismo dispositivo no se mezclen.

El guardado es best-effort y sin esperar, igual que el caché del catálogo:
si SQLite falla —sobre todo en web, donde el paquete marca el soporte como
experimental— el carrito sigue funcionando en memoria durante la sesión.

El carrito no sube a Supabase: es local al dispositivo."
```

---

## 6. Correos de autenticación y deep links

```bash
git add supabase/email_templates/
git add lib/data/datasources/auth_remote_datasource.dart
git add lib/main.dart
git add ios/Runner/Info.plist

git commit -m "feat(auth): correos en español y enlaces que abren la app

Los correos de confirmación de cuenta y recuperación de contraseña salían
con el texto por defecto de Supabase, en inglés. Se añaden dos plantillas
con la identidad de Yogo Vital, versionadas en supabase/email_templates/
junto con lo que hay que configurar en el dashboard.

Pero el problema de fondo eran los enlaces:

- signUp y resetPasswordForEmail no indicaban a dónde volver, así que
  Supabase mandaba el enlace al Site URL por defecto (localhost:3000).
- iOS no declaraba ningún esquema de URL en Info.plist. Eso no rompía solo
  los correos: el login con Google tampoco podía funcionar en iPhone.
  Android sí lo tenía declarado.
- Nadie escuchaba el evento passwordRecovery, así que el enlace abría la app
  y esta se quedaba en la pantalla de bienvenida. ResetPasswordPage solo era
  alcanzable escribiendo la ruta a mano.

Requiere añadir io.supabase.yogovital://login-callback a las Redirect URLs
del proyecto en Supabase."
```

---

## 7. Normalizar finales de línea

Va el último a propósito: reescribe 95 archivos y taparía cualquier commit
que fuera detrás.

```bash
git add .gitattributes
git add --renormalize .
git add COMMITS_PENDIENTES.md

git commit -m "chore: normalizar finales de línea a LF

95 archivos aparecían como modificados sin haber cambiado nada: android/,
ios/, las migraciones antiguas, el README. Todos por CRLF contra LF.

Eso significaba unas 7.200 líneas de ruido en cada diff, y que cualquier
merge entre ramas iba a dar conflictos falsos en archivos que nadie tocó.

.gitattributes fija LF en el repositorio y deja que cada quien tenga en su
disco lo que le corresponda."
```

---

## Al terminar

```bash
git status          # debería quedar limpio
git log --oneline -8
```

---

## Notas

**Hay archivos que tocan dos temas.** `cart_model.dart` tiene la
persistencia del carrito y el `tamanoId` de los prediseñados; `main.dart`
tiene el listener del carrito y el de recuperación de contraseña. Cada uno
va donde está su cambio principal. Si quieres separarlos de verdad,
`git add -p` deja elegir trozo por trozo.

**El commit 1 mezcla trabajo de varias semanas.** No lo dividí más porque
sus archivos se cruzan entre sí y no conozco el orden real en que lo
hiciste. Si prefieres partirlo por funcionalidad, dímelo y lo rehago.

**Nada de esto está probado en el móvil todavía.** Los deep links y los
correos solo se pueden verificar con la app instalada. Commitear ahora
protege el trabajo; probar sigue pendiente.
