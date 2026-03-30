import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _loading = false;
  final _storage = const FlutterSecureStorage();

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;

  Future<void> loadFromStorage() async {
    final idStr = await _storage.read(key: 'user_id');
    if (idStr == null) return;
    final id = int.tryParse(idStr);
    if (id == null) return;
    final u = await AuthService.instance.findUserById(id);
    _user = u;
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final u = await AuthService.instance.register(email, password);
      _user = u;
      await _storage.write(key: 'user_id', value: u.id.toString());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final u = await AuthService.instance.login(email, password);
      _user = u;
      await _storage.write(key: 'user_id', value: u.id.toString());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    await _storage.delete(key: 'user_id');
    notifyListeners();
  }
}
