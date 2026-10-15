import 'dart:convert';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.groupId,
    required this.userName,
    required this.groupName,
    required this.user,
    required this.sidebars,
    required this.verifiedAt,
    this.isOffline = false,
  });

  final String token;
  final int userId;
  final int groupId;
  final String userName;
  final String groupName;
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> sidebars;
  final DateTime verifiedAt;
  final bool isOffline;

  AuthSession asOffline() => AuthSession(
        token: token,
        userId: userId,
        groupId: groupId,
        userName: userName,
        groupName: groupName,
        user: user,
        sidebars: sidebars,
        verifiedAt: verifiedAt,
        isOffline: true,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'userId': userId,
        'groupId': groupId,
        'userName': userName,
        'groupName': groupName,
        'user': user,
        'sidebars': sidebars,
        'verifiedAt': verifiedAt.toUtc().toIso8601String(),
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(
      (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final rawSidebars = json['sidebars'];
    final sidebars = rawSidebars is List
        ? rawSidebars
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    final userId = _asInt(json['userId'] ?? user['id']);
    final groupId = _asInt(json['groupId'] ?? user['group_id']);
    final userName = (json['userName'] ?? user['nama'] ?? user['username'])
        ?.toString()
        .trim();
    final groupName =
        (json['groupName'] ?? user['group_nama'])?.toString().trim();
    final token = json['token']?.toString() ?? '';
    final verifiedAt = DateTime.tryParse(json['verifiedAt']?.toString() ?? '');

    if (token.isEmpty ||
        userId <= 0 ||
        groupId <= 0 ||
        userName == null ||
        userName.isEmpty ||
        verifiedAt == null) {
      throw const FormatException('Cache sesi autentikasi tidak valid.');
    }

    return AuthSession(
      token: token,
      userId: userId,
      groupId: groupId,
      userName: userName,
      groupName: groupName?.isNotEmpty == true ? groupName! : 'Pengguna',
      user: user,
      sidebars: sidebars,
      verifiedAt: verifiedAt.toLocal(),
    );
  }

  String encode() => jsonEncode(toJson());

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
