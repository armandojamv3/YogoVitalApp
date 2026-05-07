import 'package:dart_frog/dart_frog.dart';

// Simple HTML page served by the backend to allow resetting password when
// the frontend is not available. It reads `token` from query parameters and
// POSTs JSON to `/auth/password_reset/confirm`.

Future<Response> onRequest(RequestContext context) async {
  final params = context.request.uri.queryParameters;
  final token = params['token'] ?? '';

  final html = '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Restablecer contraseña</title>
    <style>
      body { font-family: Arial, Helvetica, sans-serif; background:#f4f6f8; padding:20px }
      .card { max-width:480px; margin:40px auto; background:white; padding:24px; border-radius:8px; box-shadow:0 6px 18px rgba(0,0,0,0.08) }
      label { display:block; margin-top:12px; font-weight:600 }
      input { width:100%; padding:10px; margin-top:6px; box-sizing:border-box }
      button { margin-top:18px; padding:12px 18px; background:#0d47a1; color:white; border:none; border-radius:6px }
      .msg { margin-top:14px; padding:10px; border-radius:6px }
    </style>
  </head>
  <body>
    <div class="card">
      <h2>Restablecer contraseña</h2>
      <p>Ingresa tu nueva contraseña y confirma.
      </p>
      <form id="resetForm">
        <label>Token</label>
        <input id="token" name="token" value="$token" />
        <label>Nueva contraseña</label>
        <input id="password" name="password" type="password" />
        <label>Confirmar contraseña</label>
        <input id="password_confirmation" name="password_confirmation" type="password" />
        <button type="submit">Confirmar</button>
      </form>
      <div id="result" class="msg"></div>
    </div>

    <script>
      const form = document.getElementById('resetForm');
      const result = document.getElementById('result');
      form.addEventListener('submit', async (e) => {
        e.preventDefault();
        result.textContent = '';
        const token = document.getElementById('token').value.trim();
        const password = document.getElementById('password').value;
        const password_confirmation = document.getElementById('password_confirmation').value;
        if (!token || !password || !password_confirmation) {
          result.style.background = '#fff3cd';
          result.textContent = 'Completa todos los campos.';
          return;
        }
        if (password !== password_confirmation) {
          result.style.background = '#f8d7da';
          result.textContent = 'Las contraseñas no coinciden.';
          return;
        }

        try {
          const resp = await fetch('/auth/password_reset/confirm', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ token, password, password_confirmation })
          });
          const body = await resp.json();
          if (resp.ok) {
            result.style.background = '#d4edda';
            result.textContent = body.message || 'Contraseña restablecida correctamente.';
          } else {
            result.style.background = '#f8d7da';
            result.textContent = body.error || JSON.stringify(body);
          }
        } catch (err) {
          result.style.background = '#f8d7da';
          result.textContent = String(err);
        }
      });
    </script>
  </body>
</html>
''';

  return Response(
      body: html, headers: {'content-type': 'text/html; charset=utf-8'});
}
