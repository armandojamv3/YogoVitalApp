// Edge Function: enviar notificaciones push por FCM.
//
// ── POR QUÉ SE REESCRIBIÓ ────────────────────────────────────────────────
// La versión anterior usaba la API antigua de FCM:
//
//     Authorization: key=${FCM_SERVER_KEY}
//
// Google la dejó obsoleta en junio de 2023 y la apagó en julio de 2024. Es
// decir: aunque se hubiera terminado de conectar, no habría funcionado
// nunca. Encaja con el comentario del repositorio que decía que "nunca
// quedó realmente conectada".
//
// Ahora se usa FCM HTTP v1, que autentica con una cuenta de servicio: se
// firma un JWT con la clave privada, se canjea por un token de acceso de
// Google y con ese token se envía. Es más trabajo, pero es lo único que
// existe hoy.
//
// ── VARIABLES DE ENTORNO ─────────────────────────────────────────────────
// En Supabase → Edge Functions → Secrets:
//
//   FIREBASE_SERVICE_ACCOUNT   el JSON completo de la clave privada,
//                              pegado tal cual (Firebase → Configuración
//                              del proyecto → Cuentas de servicio →
//                              Generar nueva clave privada)
//
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY las inyecta Supabase sola.
//
// ── QUIÉN PUEDE LLAMARLA ─────────────────────────────────────────────────
// Acepta dos formas de destinatario:
//
//   { destino: "administradores", titulo, cuerpo, pedido_id }
//   { usuario_id: "<uuid>",       titulo, cuerpo, pedido_id }
//
// La primera la usa cualquier cliente autenticado: es como avisa al negocio
// de que hizo o canceló un pedido. La función busca los administradores por
// su cuenta, así que el cliente nunca llega a conocer sus ids.
//
// La segunda exige ser el propio destinatario o ser administrador. Es la que
// usa el admin para avisar al cliente de un cambio de estado.
//
// Sin estas comprobaciones, cualquiera con la anon key podría mandar avisos
// falsos a cualquier usuario a nombre del negocio.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

interface CuentaDeServicio {
  project_id: string;
  client_email: string;
  private_key: string;
}

/** Convierte la clave PEM de la cuenta de servicio en una CryptoKey. */
async function importarClave(pem: string): Promise<CryptoKey> {
  const cuerpo = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binario = Uint8Array.from(atob(cuerpo), (c) => c.charCodeAt(0));

  return await crypto.subtle.importKey(
    "pkcs8",
    binario.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/**
 * Token de acceso de Google, vía el flujo JWT bearer de OAuth2.
 *
 * Se cachea en memoria: los tokens duran una hora y el arranque en frío de
 * la función es frecuente, pero mientras la instancia siga viva se reutiliza
 * en vez de pedir uno nuevo en cada notificación.
 */
let tokenCacheado: { valor: string; expiraEn: number } | null = null;

async function obtenerTokenDeAcceso(
  cuenta: CuentaDeServicio,
): Promise<string> {
  const ahora = Math.floor(Date.now() / 1000);
  if (tokenCacheado && tokenCacheado.expiraEn > ahora + 60) {
    return tokenCacheado.valor;
  }

  const clave = await importarClave(cuenta.private_key);
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: cuenta.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      exp: getNumericDate(3600),
      iat: getNumericDate(0),
    },
    clave,
  );

  const respuesta = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!respuesta.ok) {
    throw new Error(`OAuth2 rechazó la clave: ${await respuesta.text()}`);
  }

  const datos = await respuesta.json();
  tokenCacheado = {
    valor: datos.access_token,
    expiraEn: ahora + (datos.expires_in ?? 3600),
  };
  return datos.access_token;
}

Deno.serve(async (req) => {
  try {
    const cuerpoPeticion = await req.json();
    const { destino, usuario_id, evento, pedido_id } = cuerpoPeticion;
    let { titulo, cuerpo } = cuerpoPeticion;

    if (!destino && !usuario_id) {
      return json({ error: "Falta destino o usuario_id" }, 400);
    }
    if (!titulo && !evento) {
      return json({ error: "Falta titulo o evento" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // ── Autorización ─────────────────────────────────────────────────────
    const token = (req.headers.get("Authorization") ?? "")
      .replace(/^Bearer\s+/i, "");
    const { data: { user: quienLlama }, error: errorAuth } = await supabase.auth
      .getUser(token);

    if (errorAuth || !quienLlama) {
      return json({ error: "No autenticado" }, 401);
    }

    // ── A quién va ───────────────────────────────────────────────────────
    let destinatarios: string[];

    if (destino === "administradores") {
      // Cualquier usuario autenticado puede avisar al negocio. Los ids se
      // resuelven aquí dentro, nunca los ve el cliente.
      const { data: admins } = await supabase
        .from("usuarios")
        .select("id")
        .eq("rol", "administrador");
      destinatarios = (admins ?? []).map((a) => a.id);
    } else {
      if (quienLlama.id !== usuario_id) {
        const { data: perfil } = await supabase
          .from("usuarios")
          .select("rol")
          .eq("id", quienLlama.id)
          .single();

        if (perfil?.rol !== "administrador") {
          return json(
            { error: "No autorizado para notificar a este usuario" },
            403,
          );
        }
      }
      destinatarios = [usuario_id];
    }

    if (destinatarios.length === 0) {
      return json({ enviados: 0, motivo: "sin destinatarios" });
    }

    // ── Texto del mensaje ────────────────────────────────────────────────
    // Cuando llega `evento`, el texto se compone aquí leyendo el pedido de
    // verdad. Antes lo armaba la app y salía mucho más pobre que la
    // notificación in-app: "Mora · 2 Litros" frente a "Juan pidió Tropical
    // Explosión (x2) por $74.000".
    //
    // Y hay una razón de fondo para no dejarlo en el cliente: el total. La
    // app tiene su propia idea del precio, y esa discrepancia entre lo que
    // calcula el cliente y lo que cobra el servidor es exactamente el bug
    // que costó una semana de pedidos mal cobrados (migración 0043). El
    // texto sale de la misma fila que se cobró.
    if (evento && pedido_id) {
      const compuesto = await componerMensaje(supabase, evento, pedido_id);
      titulo = titulo ?? compuesto.titulo;
      cuerpo = cuerpo ?? compuesto.cuerpo;
    }

    if (!titulo) return json({ error: "No se pudo determinar el título" }, 400);

    // ── Tokens de los destinatarios ──────────────────────────────────────
    const { data: dispositivos } = await supabase
      .from("dispositivos")
      .select("token")
      .in("usuario_id", destinatarios);

    if (!dispositivos || dispositivos.length === 0) {
      // No es un error: el usuario simplemente no tiene la app instalada, o
      // rechazó las notificaciones. La notificación in-app ya se guardó.
      return json({ enviados: 0, motivo: "sin dispositivos registrados" });
    }

    // ── Envío ────────────────────────────────────────────────────────────
    const cuenta: CuentaDeServicio = JSON.parse(
      Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!,
    );
    const accessToken = await obtenerTokenDeAcceso(cuenta);
    const url =
      `https://fcm.googleapis.com/v1/projects/${cuenta.project_id}/messages:send`;

    let enviados = 0;
    const tokensMuertos: string[] = [];

    for (const { token: fcmToken } of dispositivos) {
      const respuesta = await fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: { title: titulo, body: cuerpo ?? "" },
            data: pedido_id ? { pedido_id: String(pedido_id) } : {},
            android: { priority: "HIGH" },
          },
        }),
      });

      if (respuesta.ok) {
        enviados++;
      } else {
        const detalle = await respuesta.text();
        // 404 / UNREGISTERED significa que ese token ya no existe: la app se
        // desinstaló o se borraron sus datos. Se limpian para no seguir
        // intentándolo en cada pedido.
        if (respuesta.status === 404 || detalle.includes("UNREGISTERED")) {
          tokensMuertos.push(fcmToken);
        } else {
          console.error(`FCM rechazó el envío (${respuesta.status}): ${detalle}`);
        }
      }
    }

    if (tokensMuertos.length > 0) {
      await supabase.from("dispositivos").delete().in("token", tokensMuertos);
    }

    return json({ enviados, limpiados: tokensMuertos.length });
  } catch (e) {
    console.error("send-notification falló:", e);
    return json({ error: String(e) }, 500);
  }
});

/**
 * Arma el texto del aviso leyendo el pedido real.
 *
 * Mismo formato que usan las RPC crear_pedido y cancelar_pedido para la
 * notificación in-app, para que los dos canales digan lo mismo.
 */
async function componerMensaje(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  evento: string,
  pedidoId: string,
): Promise<{ titulo: string; cuerpo: string }> {
  const respaldo = evento === "cancelado"
    ? { titulo: "Pedido cancelado", cuerpo: "Un cliente canceló su pedido" }
    : { titulo: "Nuevo pedido", cuerpo: "Entró un pedido nuevo" };

  try {
    const { data: pedido } = await supabase
      .from("pedidos")
      .select(`
        total, cantidad, cliente_id,
        sabores(nombre),
        tamanos_yogur(nombre),
        predisenhados(nombre)
      `)
      .eq("id", pedidoId)
      .single();

    if (!pedido) return respaldo;

    const { data: cliente } = await supabase
      .from("usuarios")
      .select("nombre")
      .eq("id", pedido.cliente_id)
      .single();

    const quien = cliente?.nombre ?? "Un cliente";
    const producto = pedido.predisenhados?.nombre ??
      pedido.sabores?.nombre ??
      "un yogur";
    const tamano = pedido.tamanos_yogur?.nombre;
    const veces = (pedido.cantidad ?? 1) > 1 ? ` (x${pedido.cantidad})` : "";
    const precio = formatearPesos(pedido.total);

    if (evento === "cancelado") {
      return {
        titulo: "Pedido cancelado",
        cuerpo: `${quien} canceló su pedido de ${producto} — ${precio}`,
      };
    }

    return {
      titulo: "Nuevo pedido",
      cuerpo: `${quien} pidió ${producto}${tamano ? ` ${tamano}` : ""}` +
        `${veces} — ${precio}`,
    };
  } catch (e) {
    console.error("No se pudo componer el mensaje:", e);
    return respaldo;
  }
}

/** 74000 → "$74.000" (formato colombiano, sin decimales). */
function formatearPesos(valor: number | string | null): string {
  const numero = Math.round(Number(valor ?? 0));
  return "$" + numero.toLocaleString("es-CO", { maximumFractionDigits: 0 });
}

function json(cuerpo: unknown, status = 200): Response {
  return new Response(JSON.stringify(cuerpo), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
