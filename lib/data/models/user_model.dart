class UserModel {
  final int? id;
  final String email;
  final String passwordHash;
  final String salt;
  final int createdAt;

  UserModel({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> m) {
    return UserModel(
      id: m['id'] as int?,
      email: m['email'] as String,
      passwordHash: m['password_hash'] as String,
      salt: m['salt'] as String,
      createdAt: m['created_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password_hash': passwordHash,
      'salt': salt,
      'created_at': createdAt,
    };
  }
}
