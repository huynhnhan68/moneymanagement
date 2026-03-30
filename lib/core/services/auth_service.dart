import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../data/datasources/db_helper.dart';
import '../../data/models/user_model.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  final _uuid = const Uuid();

  Future<UserModel> register(String email, String password) async {
    final db = await DBHelper.instance.database;

    // check exists
    final existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (existing.isNotEmpty) {
      throw Exception('Email đã tồn tại');
    }

    final salt = _uuid.v4();
    final hash = _hashPassword(password, salt);
    final createdAt = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insert('users', {
      'email': email,
      'password_hash': hash,
      'salt': salt,
      'created_at': createdAt,
    });

    return UserModel(
      id: id,
      email: email,
      passwordHash: hash,
      salt: salt,
      createdAt: createdAt,
    );
  }

  Future<UserModel> login(String email, String password) async {
    final db = await DBHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (rows.isEmpty) throw Exception('Không tìm thấy tài khoản');

    final user = UserModel.fromMap(rows.first);
    final hash = _hashPassword(password, user.salt);
    if (hash != user.passwordHash) throw Exception('Mật khẩu không đúng');

    return user;
  }

  Future<UserModel?> findUserById(int id) async {
    final db = await DBHelper.instance.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(salt + password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
