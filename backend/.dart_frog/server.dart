// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';


import '../routes/reset-password.dart' as reset_password;
import '../routes/protected.dart' as protected;
import '../routes/tamanos-yogur/index.dart' as tamanos_yogur_index;
import '../routes/sabores/index.dart' as sabores_index;
import '../routes/sabores/[id].dart' as sabores_$id;
import '../routes/sabores/[id]/pedidos-activos.dart' as sabores_$id_pedidos_activos;
import '../routes/pedidos/index.dart' as pedidos_index;
import '../routes/pedidos/[id].dart' as pedidos_$id;
import '../routes/pedidos/[id]/items.dart' as pedidos_$id_items;
import '../routes/pedidos/[id]/cancel.dart' as pedidos_$id_cancel;
import '../routes/frutas/index.dart' as frutas_index;
import '../routes/frutas/[id].dart' as frutas_$id;
import '../routes/extras/index.dart' as extras_index;
import '../routes/extras/[id].dart' as extras_$id;
import '../routes/calificaciones/index.dart' as calificaciones_index;
import '../routes/auth/verify.dart' as auth_verify;
import '../routes/auth/resend_verification.dart' as auth_resend_verification;
import '../routes/auth/register.dart' as auth_register;
import '../routes/auth/password_reset_confirm.dart' as auth_password_reset_confirm;
import '../routes/auth/login.dart' as auth_login;
import '../routes/auth/index.dart' as auth_index;
import '../routes/auth/password_reset/confirm.dart' as auth_password_reset_confirm;

import '../routes/_middleware.dart' as middleware;

void main() async {
  final address = InternetAddress.tryParse('') ?? InternetAddress.anyIPv6;
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  hotReload(() => createServer(address, port));
}

Future<HttpServer> createServer(InternetAddress address, int port) {
  final handler = Cascade().add(buildRootHandler()).handler;
  return serve(handler, address, port);
}

Handler buildRootHandler() {
  final pipeline = const Pipeline().addMiddleware(middleware.middleware);
  final router = Router()
    ..mount('/', (context) => buildHandler()(context))
    ..mount('/tamanos-yogur', (context) => buildTamanosYogurHandler()(context))
    ..mount('/sabores', (context) => buildSaboresHandler()(context))
    ..mount('/sabores/<id>', (context,id,) => buildSabores$idHandler(id,)(context))
    ..mount('/pedidos', (context) => buildPedidosHandler()(context))
    ..mount('/pedidos/<id>', (context,id,) => buildPedidos$idHandler(id,)(context))
    ..mount('/frutas', (context) => buildFrutasHandler()(context))
    ..mount('/extras', (context) => buildExtrasHandler()(context))
    ..mount('/calificaciones', (context) => buildCalificacionesHandler()(context))
    ..mount('/auth', (context) => buildAuthHandler()(context))
    ..mount('/auth/password_reset', (context) => buildAuthPasswordResetHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/protected', (context) => protected.onRequest(context,))..all('/reset-password', (context) => reset_password.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildTamanosYogurHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => tamanos_yogur_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildSaboresHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => sabores_$id.onRequest(context,id,))..all('/', (context) => sabores_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildSabores$idHandler(String id,) {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/pedidos-activos', (context) => sabores_$id_pedidos_activos.onRequest(context,id,));
  return pipeline.addHandler(router);
}

Handler buildPedidosHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => pedidos_$id.onRequest(context,id,))..all('/', (context) => pedidos_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildPedidos$idHandler(String id,) {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/cancel', (context) => pedidos_$id_cancel.onRequest(context,id,))..all('/items', (context) => pedidos_$id_items.onRequest(context,id,));
  return pipeline.addHandler(router);
}

Handler buildFrutasHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => frutas_$id.onRequest(context,id,))..all('/', (context) => frutas_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildExtrasHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/<id>', (context,id,) => extras_$id.onRequest(context,id,))..all('/', (context) => extras_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildCalificacionesHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => calificaciones_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildAuthHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/login', (context) => auth_login.onRequest(context,))..all('/password_reset_confirm', (context) => auth_password_reset_confirm.onRequest(context,))..all('/register', (context) => auth_register.onRequest(context,))..all('/resend_verification', (context) => auth_resend_verification.onRequest(context,))..all('/verify', (context) => auth_verify.onRequest(context,))..all('/', (context) => auth_index.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildAuthPasswordResetHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/confirm', (context) => auth_password_reset_confirm.onRequest(context,));
  return pipeline.addHandler(router);
}

