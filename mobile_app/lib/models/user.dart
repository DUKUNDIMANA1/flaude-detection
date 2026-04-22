// lib/models/user.dart
class User {
  final int id;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    username: json['username'] ?? '',
    email: json['email'] ?? '',
    role: json['role'] ?? 'analyst',
    isActive: json['is_active'] ?? true,
    createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    lastLogin: json['last_login'] != null
        ? DateTime.tryParse(json['last_login'])
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'role': role,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'last_login': lastLogin?.toIso8601String(),
  };
}
