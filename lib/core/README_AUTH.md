Usage to connect frontend to backend

1) Add the files created:
 - `lib/core/network/api_client.dart`
 - `lib/data/datasources/auth_remote_datasource.dart`
 - `lib/data/repositories/auth_repository.dart`

2) Set API base URL depending on where you run the backend:
 - Android emulator: use `http://10.0.2.2:8080`
 - iOS simulator: use `http://localhost:8080`
 - Physical device: use `http://<PC_IP>:8080` (ensure firewall allows the port)

3) Example initialization (e.g. in `main.dart` before running app):

```dart
import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'data/datasources/auth_remote_datasource.dart';
import 'data/repositories/auth_repository.dart';

void main() {
  const baseUrl = 'http://10.0.2.2:8080'; // change as needed
  final apiClient = ApiClient(baseUrl: baseUrl);
  final authRemote = AuthRemoteDataSource(apiClient: apiClient);
  final authRepository = AuthRepository(remote: authRemote);
  runApp(MyApp(authRepository: authRepository));
}
```

4) Example usage in a login button handler:

```dart
// assume you have an instance of AuthRepository called `authRepository`
try {
  final res = await authRepository.login(emailController.text, passwordController.text);
  final token = res['token'];
  // navigate to home when success
} catch (e) {
  // show error (ApiException.body contains server error map)
}
```

5) Notes
 - The repository stores the JWT in `flutter_secure_storage` under key `jwt_token` after login.
 - Protected requests should include header `Authorization: Bearer <token>`; you can read token with `await authRepository.getToken()` and attach to requests manually.
 - After making changes to `pubspec.yaml`, run `flutter pub get`.

If quieres puedo:
- (A) Conectar automáticamente `login_page.dart` y `register_page.dart` existentes para que llamen al `AuthRepository` (haré los parches). 
- (B) Dejar los archivos y darte pasos para que los integres manualmente.

Responde A o B.