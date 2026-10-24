import 'package:latlong2/latlong.dart';
import 'player.dart';

enum GamePhase {
  lobby,
  headStart,
  hunting,
  gameOver,
}

extension GamePhaseExtension on GamePhase {
  static GamePhase fromString(String? status) {
    switch (status?.toUpperCase()) {
      case 'HEAD_START':
        return GamePhase.headStart;
      case 'HUNTING':
        return GamePhase.hunting;
      case 'FINISHED':
        return GamePhase.gameOver;
      default:
        return GamePhase.lobby;
    }
  }
}

class PlayerStatsModel {
  final int distanceTraveledMeters;
  final int cardsUsedCount;
  final int totalAdrenalineEarned;
  final int timeSurvivedSeconds;
  final int tagsCount;

  PlayerStatsModel({
    required this.distanceTraveledMeters,
    required this.cardsUsedCount,
    required this.totalAdrenalineEarned,
    required this.timeSurvivedSeconds,
    required this.tagsCount,
  });

  factory PlayerStatsModel.fromJson(Map<String, dynamic> json) {
    return PlayerStatsModel(
      distanceTraveledMeters: (json['distanceTraveledMeters'] as num?)?.toInt() ?? 0,
      cardsUsedCount: (json['cardsUsedCount'] as num?)?.toInt() ?? 0,
      totalAdrenalineEarned: (json['totalAdrenalineEarned'] as num?)?.toInt() ?? 0,
      timeSurvivedSeconds: (json['timeSurvivedSeconds'] as num?)?.toInt() ?? 0,
      tagsCount: (json['tagsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class GameOverPlayerModel {
  final String id;
  final String nickname;
  final PlayerRole role;
  final bool isAlive;
  final PlayerStatsModel stats;

  GameOverPlayerModel({
    required this.id,
    required this.nickname,
    required this.role,
    required this.isAlive,
    required this.stats,
  });

  factory GameOverPlayerModel.fromJson(Map<String, dynamic> json) {
    return GameOverPlayerModel(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? '',
      role: PlayerRoleExtension.fromString(json['role']),
      isAlive: json['isAlive'] ?? false,
      stats: PlayerStatsModel.fromJson(json['stats'] ?? {}),
    );
  }
}

class GameOverDataModel {
  final String winner;
  final String reason;
  final int durationSeconds;
  final List<GameOverPlayerModel> playersStats;

  GameOverDataModel({
    required this.winner,
    required this.reason,
    required this.durationSeconds,
    required this.playersStats,
  });

  factory GameOverDataModel.fromJson(Map<String, dynamic> json) {
    final rawStats = (json['playersStats'] as List<dynamic>?) ?? [];
    return GameOverDataModel(
      winner: json['winner'] ?? 'CATS',
      reason: json['reason'] ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      playersStats: rawStats.map((p) => GameOverPlayerModel.fromJson(p)).toList(),
    );
  }
}

class SupplyPoiModel {
  final String id;
  final String name;
  final LatLng position;
  final bool isAvailable;

  SupplyPoiModel({
    required this.id,
    required this.name,
    required this.position,
    required this.isAvailable,
  });

  factory SupplyPoiModel.fromJson(Map<String, dynamic> json) {
    return SupplyPoiModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Ravitaillement',
      position: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      isAvailable: json['isAvailable'] ?? true,
    );
  }
}

class GameSessionModel {
  final String roomCode;
  final GamePhase phase;
  final String hostId;
  final LatLng zoneCenter;
  final double currentRadius;
  final double initialRadius;
  final int currentWaveIndex;
  final bool isWarningShrink;
  final double? targetRadius;
  final int? shrinkWarningEndsAt;
  final List<PlayerModel> players;
  final List<SupplyPoiModel> pois;
  final int? headStartEndsAt;
  final int? nextRadarPingAt;
  final GameOverDataModel? gameOverData;

  GameSessionModel({
    required this.roomCode,
    required this.phase,
    required this.hostId,
    required this.zoneCenter,
    required this.currentRadius,
    required this.initialRadius,
    required this.currentWaveIndex,
    required this.isWarningShrink,
    this.targetRadius,
    this.shrinkWarningEndsAt,
    required this.players,
    required this.pois,
    this.headStartEndsAt,
    this.nextRadarPingAt,
    this.gameOverData,
  });

  factory GameSessionModel.fromJson(Map<String, dynamic> json) {
    final zone = json['zone'] ?? {};
    final center = zone['center'] ?? {};
    final rawPlayers = (json['players'] as List<dynamic>?) ?? [];
    final rawPois = (json['pois'] as List<dynamic>?) ?? [];

    return GameSessionModel(
      roomCode: json['code'] ?? '',
      phase: GamePhaseExtension.fromString(json['status']),
      hostId: json['hostId'] ?? '',
      zoneCenter: LatLng(
        (center['latitude'] as num?)?.toDouble() ?? 48.8566,
        (center['longitude'] as num?)?.toDouble() ?? 2.3522,
      ),
      currentRadius: (zone['currentRadius'] as num?)?.toDouble() ?? 800.0,
      initialRadius: (zone['initialRadius'] as num?)?.toDouble() ?? 800.0,
      currentWaveIndex: (zone['currentWaveIndex'] as num?)?.toInt() ?? 1,
      isWarningShrink: zone['isWarningShrink'] ?? false,
      targetRadius: (zone['targetRadius'] as num?)?.toDouble(),
      shrinkWarningEndsAt: zone['shrinkWarningEndsAt'],
      players: rawPlayers.map((p) => PlayerModel.fromJson(p)).toList(),
      pois: rawPois.map((p) => SupplyPoiModel.fromJson(p)).toList(),
      headStartEndsAt: json['headStartEndsAt'],
      nextRadarPingAt: json['nextRadarPingAt'],
      gameOverData: json['gameOverData'] != null ? GameOverDataModel.fromJson(json['gameOverData']) : null,
    );
  }
}
