# Correos de autenticación

Las plantillas de esta carpeta **no las lee la app**. Son una copia
versionada de lo que hay que pegar a mano en el dashboard de Supabase, para
que quede en el repositorio y no se pierda (mismo problema que ya pasó con
las columnas `tipo` y `costo_envio`, que se crearon en el dashboard y nadie
las anotó).

| Archivo | Dónde va en Supabase |
|---|---|
| `01_confirmar_cuenta.html` | Authentication → **Emails** (sección NOTIFICATIONS) → *Confirm signup* |
| `02_recuperar_password.html` | Authentication → **Emails** (sección NOTIFICATIONS) → *Reset password* |

> Ojo: **OAuth Apps** no tiene nada que ver con esto. Sirve para que el
> proyecto actúe como proveedor de identidad para aplicaciones de terceros.

Asuntos sugeridos:

- Confirm signup → `Confirma tu cuenta en Yogo Vital`
- Reset password → `Restablece tu contraseña de Yogo Vital`

---

## Configuración necesaria para que los enlaces funcionen

Pegar el HTML no basta. Si los enlaces no apuntan a la app, el correo se ve
bien y no sirve para nada.

### 1. Redirect URLs — el paso que más se olvida

Authentication → **URL Configuration** (sección CONFIGURATION) →
**Redirect URLs**, añadir:

```
io.supabase.yogovital://login-callback
```

Supabase rechaza cualquier `redirectTo` que no esté en esa lista y cae de
vuelta al Site URL **sin avisar ni dar error**. Es la causa más habitual de
"el enlace me lleva a localhost".

### 2. Site URL

El mismo apartado. Es el destino por defecto cuando no se indica otro —
sobre todo, el que usa la versión web. Por defecto viene
`http://localhost:3000`, que solo sirve mientras desarrollas.

### 3. Confirmación de correo activada

Authentication → **Sign In / Providers** → **Email** → *Confirm email*.

Si está desactivado, el correo de confirmación no se envía nunca, aunque la
app muestre el mensaje de "revisa tu bandeja". Conviene comprobarlo antes de
dar por rota la plantilla.

---

## Límite de correos

El servidor SMTP que trae Supabase por defecto está pensado solo para
desarrollo: **unos pocos correos por hora**, y solo a direcciones de los
miembros del proyecto. En cuanto haya usuarios reales hay que configurar un
SMTP propio en Authentication → Emails → SMTP Settings (Resend, SendGrid,
Amazon SES o similar).

Si en las pruebas un correo no llega, lo primero que hay que descartar es
este límite, no la plantilla.

---

## Cómo probar

1. Registrar una cuenta con un correo real y ver que llega el de
   confirmación.
2. Desde el login, "olvidé mi contraseña", y comprobar que el enlace **abre
   la app** directamente en la pantalla de nueva contraseña.

Ese segundo punto es el que más suele fallar: si la app se abre pero se
queda en la pantalla de bienvenida, revisar el listener de
`AuthChangeEvent.passwordRecovery` en `lib/main.dart`.
