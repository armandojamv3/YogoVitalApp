// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';


import '../routes/reset-password.dart' as reset_password;
import '../routes/protected.dart' as protected;
import '../routes/auth/verify.dart' as auth_verify;
import '../routes/auth/resend_verification.dart' as auth_resend_verification;
import '../routes/auth/register.dart' as auth_register;
import '../routes/auth/password_reset_confirm.dart' as auth_password_reset_confirm;
import '../routes/auth/logout.dart' as auth_logout;
import '../routes/auth/login.dart' as auth_login;
import '../routes/auth/check-email.dart' as auth_check_email;
import '../routes/auth/password_reset/index.dart' as auth_password_reset_index;
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
    ..mount('/auth/password_reset', (context) => buildAuthPasswordResetHandler()(context))
    ..mount('/auth', (context) => buildAuthHandler()(context))
    ..mount('/', (context) => buildHandler()(context));
  return pipeline.addHandler(router);
}

Handler buildAuthPasswordResetHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/', (context) => auth_password_reset_index.onRequest(context,))..all('/confirm', (context) => auth_password_reset_confirm.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildAuthHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/verify', (context) => auth_verify.onRequest(context,))..all('/resend_verification', (context) => auth_resend_verification.onRequest(context,))..all('/register', (context) => auth_register.onRequest(context,))..all('/password_reset_confirm', (context) => auth_password_reset_confirm.onRequest(context,))..all('/logout', (context) => auth_logout.onRequest(context,))..all('/login', (context) => auth_login.onRequest(context,))..all('/check-email', (context) => auth_check_email.onRequest(context,));
  return pipeline.addHandler(router);
}

Handler buildHandler() {
  final pipeline = const Pipeline();
  final router = Router()
    ..all('/reset-password', (context) => reset_password.onRequest(context,))..all('/protected', (context) => protected.onRequest(context,));
  return pipeline.addHandler(router);
}

