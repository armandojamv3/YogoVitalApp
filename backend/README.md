Dart Frog backend for YogoVitalApp

Quick start

1. Instala Dart SDK: https://dart.dev/get-dart
2. Instala Dart Frog CLI (una sola vez):

```powershell
dart pub global activate dart_frog_cli
# Asegúrate de tener %USERPROFILE%\AppData\Local\Pub\Cache\bin en tu PATH
```

3. Desde la carpeta `backend/` instala dependencias:

```powershell
dart pub get
```

4. Copia `.env.example` a `.env` y ajusta si hace falta.

5. Ejecuta en modo desarrollo (hot reload):

```powershell
dart_frog dev
```

6. Rutas disponibles
- POST `/auth/register` - crea usuario
- POST `/auth/login` - login y devuelve JWT

7. Probar con Postman
- Registro: POST http://localhost:4000/auth/register
  Body JSON: { "email": "user@example.com", "password": "MiPass123", "name": "Jose" }
- Login: POST http://localhost:4000/auth/login

Notas
- Si pruebas desde un emulador Android usa `http://10.0.2.2:4000`.
- No subas tu `.env` al repositorio.
YogoVital backend (Dart, shelf)

Quick start

1. Instala Dart SDK: https://dart.dev/get-dart
2. Desde esta carpeta `backend/` instala dependencias:

```powershell
dart pub get
```

3. Copia `.env.example` a `.env` y ajusta si hace falta:

```
DATABASE_URL=postgresql://postgres:Jamv3123@localhost:5432/yogo_vital_db
JWT_SECRET=un_valor_secreto
PORT=4000
```

4. Ejecuta el server:

```powershell
dart run bin/server.dart
```

5. Probar endpoints con Postman (ejemplos):

- POST http://localhost:4000/auth/register
  Body JSON: { "email": "user@example.com", "password": "MiPass123", "name": "Juan" }
- POST http://localhost:4000/auth/login
  Body JSON: { "email": "user@example.com", "password": "MiPass123" }

Notes
- Si pruebas desde un emulador Android usa `http://10.0.2.2:4000`.
- No comites `.env` con secretos.
