import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;
  User? _user;
  late final StreamSubscription<AuthState> _sub;

  AuthProvider(this._repo) {
    _user = _repo.currentUser;
    _sub = _repo.onAuthStateChange.listen((state) {
      _user = state.session?.user;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  User? get currentUser => _user;
  bool get isAuthenticated => _user != null;

  String get displayName =>
      _user?.userMetadata?['nombre'] as String? ?? _user?.email ?? '';

  String get email => _user?.email ?? '';

  String get telefono =>
      _user?.userMetadata?['telefono'] as String? ?? '';
}
