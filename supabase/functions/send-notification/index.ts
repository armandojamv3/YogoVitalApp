// Supabase Edge Function — send-notification (Sprint 8)
// Envía push notification via FCM cuando el admin cambia el estado de un pedido.
// Deploy: supabase functions deploy send-notification

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY") ?? "";

const mensajes: Record<string, string> = {
  "En preparación": "Tu yogur está siendo preparado 🍶",
  "En camino": "Tu pedido está en camino 🛵",
  "Entregado": "¡Tu pedido ha llegado! ¡Disfrútalo! 🎉",
  "Cancelado": "Tu pedido fue cancelado ❌",
};

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const { cliente_id, nuevo_estado, pedido_id } = await req.json();

    if (!cliente_id || !nuevo_estado) {
      return new Response(
        JSON.stringify({ error: "cliente_id y nuevo_estado son requeridos" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Obtener fcm_token del cliente
    const { data: usuario, error } = await supabase
      .from("usuarios")
      .select("fcm_token, nombre")
      .eq("id", cliente_id)
      .single();

    if (error || !usuario?.fcm_token) {
      // Sin token: no hay notificación pero no es error
      return new Response(
        JSON.stringify({ ok: false, reason: "No FCM token" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const mensaje = mensajes[nuevo_estado] ?? `Tu pedido cambió a: ${nuevo_estado}`;

    // Enviar push notification via FCM HTTP v1
    const fcmResponse = await fetch(
      "https://fcm.googleapis.com/fcm/send",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `key=${FCM_SERVER_KEY}`,
        },
        body: JSON.stringify({
          to: usuario.fcm_token,
          notification: {
            title: "Yogo Vital — Actualización de pedido",
            body: mensaje,
            sound: "default",
          },
          data: {
            pedido_id: pedido_id ?? "",
            nuevo_estado,
          },
          priority: "high",
        }),
      },
    );

    const fcmResult = await fcmResponse.json();

    return new Response(
      JSON.stringify({ ok: true, fcm: fcmResult }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
