# Diagramas corregidos — Yogo Vital

Estos reemplazan las Figuras 5 a 16 del capítulo "4.7 Diseño Lógico" y "4.8 Diseño Físico", ajustadas a lo que la app realmente hace (verificado contra el código y las migraciones de Supabase).

| Figura original | Título original | Qué pasó | Archivo nuevo |
|---|---|---|---|
| 5 | Proceso de pago (pasarela) | Reemplazada — no hay pasarela, solo texto de método de pago | `figura5_metodo_pago.puml` |
| 6 | Asignación de repartidor | Reemplazada — no hay repartidores ni geolocalización; es el admin cambiando el estado | `figura6_cambio_estado_admin.puml` |
| 7 | Proceso completo de pedido | Reconstruida con el flujo real de principio a fin | `figura7_proceso_pedido.puml` |
| 8 | Preparación en cocina | **Eliminada** — no existe módulo de cocina separado; "En preparación" es solo un estado que el admin marca (ver Figura 6) | — |
| 9 | Gestión de inventario | Reemplazada — no hay stock ni órdenes de compra; es el CRUD del catálogo (sabores/frutas/extras/promociones) | `figura9_gestion_catalogo_admin.puml` |
| 10 | Proceso de reembolso | Reemplazada — no hay pasarela ni reembolsos monetarios; es la cancelación de pedido por el cliente | `figura10_cancelacion_pedido.puml` |
| 11 | Gestión de usuarios | Reemplazada — el admin no crea/edita cuentas; es el flujo real de registro/login/rol | `figura11_registro_login_rol.puml` |
| 12 | Generar reporte (Admin) | Reemplazada — no hay reportes estadísticos; es la calificación de pedidos por el cliente | `figura12_calificar_pedido.puml` |
| 13 | Diagrama de clases | Reconstruido con las clases/modelos reales de Dart | `figura13_clases.puml` |
| 14 | Diagrama Entidad-Relación (ERD) | Reconstruido con las 16 tablas reales de Supabase | `figura14_erd.puml` |
| 15 | Componentes — arquitectura lógica | Ya corregido antes | `arquitectura_yogo_vital.puml` |
| 16 | Despliegue — nodos básicos | Ya corregido antes | `arquitectura_fisica_yogo_vital.puml` |

**Recomendación de renumeración:** como la Figura 8 desaparece, si quieres mantener la numeración consecutiva en el documento final, cada figura de la 9 en adelante se recorre un número hacia atrás (9→8, 10→9, 11→10, 12→11, 13→12, 14→13, 15→14, 16→15). Si prefieres no renumerar todo el documento (por las referencias cruzadas en el texto), también es válido dejar un salto de la 7 a la 9 con una nota al pie aclarando la fusión con la Figura 6.

## Cómo verlos
Pega el contenido de cada `.puml` en https://www.planttext.com o ábrelo con la extensión PlantUML de VS Code (`Alt+D` para vista previa). Todos usan el mismo estilo visual que tu diagrama original.
