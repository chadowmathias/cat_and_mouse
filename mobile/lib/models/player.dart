enum PlayerRole {
  none,
  cat,
  mouse,
}

extension PlayerRoleExtension on PlayerRole {
  static PlayerRole fromString(String? role) {
    switch (role?.toUpperCase()) {
      case 'CAT':
        return PlayerRole.cat;
      case 'MOUSE':
        return PlayerRole.mouse;
      default:
        return PlayerRole.none;
    }
  }

  String get displayName {
    switch (this) {
      case PlayerRole.cat:
        return '🐱 CHAT';
      case PlayerRole.mouse:
        return '🐭 SOURIS';
      case PlayerRole.none:
        return 'En attente...';
    }
  }
}

class PlayerModel {
  final String id;
  final String nickname;
  final PlayerRole role;
  final bool isHost;
  final bool isAlive;
  final int adrenalinePoints;
  final String? bleSessionToken;
  final double? latitude;
  final double? longitude;

  PlayerModel({
    required this.id,
    required this.nickname,
    required this.role,
    required this.isHost,
    required this.isAlive,
    required this.adrenalinePoints,
    this.bleSessionToken,
    this.latitude,
    this.longitude,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? 'Joueur',
      role: PlayerRoleExtension.fromString(json['role']),
      isHost: json['isHost'] ?? false,
      isAlive: json['isAlive'] ?? true,
      adrenalinePoints: json['adrenalinePoints'] ?? 0,
      bleSessionToken: json['bleSessionToken'],
      latitude: json['location'] != null ? (json['location']['latitude'] as num).toDouble() : null,
      longitude: json['location'] != null ? (json['location']['longitude'] as num).toDouble() : null,
    );
  }
}
