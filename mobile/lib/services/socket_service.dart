import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/game_session.dart';
import '../models/player.dart';
import 'haptic_service.dart';

class SocketService extends ChangeNotifier {
  IO.Socket? _socket;

  bool _isConnected = false;
  String? _selfId;
  PlayerRole _myRole = PlayerRole.none;
  String? _myBleToken;
  int _adrenalinePoints = 30;
  int? _sonarDistanceMeters;
  GameSessionModel? _currentSession;
  String? _zoneWarningMessage;
  String? _waveWarningMessage;
  String? _overspeedWarningMessage;
  String? _eliminationMessage;
  String? _cardFeedbackMessage;
  bool _isGameOver = false;
  List<String> _gameFeed = [];
  List<Map<String, dynamic>> _radarMicePositions = [];

  // Getters
  bool get isConnected => _isConnected;
  String? get selfId => _selfId;
  PlayerRole get myRole => _myRole;
  String? get myBleToken => _myBleToken;
  int get adrenalinePoints => _adrenalinePoints;
  int? get sonarDistanceMeters => _sonarDistanceMeters;
  GameSessionModel? get currentSession => _currentSession;
  String? get zoneWarningMessage => _zoneWarningMessage;
  String? get waveWarningMessage => _waveWarningMessage;
  String? get overspeedWarningMessage => _overspeedWarningMessage;
  String? get eliminationMessage => _eliminationMessage;
  String? get cardFeedbackMessage => _cardFeedbackMessage;
  bool get isGameOver => _isGameOver;
  List<String> get gameFeed => _gameFeed;
  List<Map<String, dynamic>> get radarMicePositions => _radarMicePositions;

  bool get isHost => _currentSession != null && _currentSession!.hostId == _selfId;

  void connect({String serverUrl = 'http://10.0.2.2:3000'}) {
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('[Socket] Connecté: ${_socket!.id}');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('[Socket] Déconnecté');
      notifyListeners();
    });

    _socket!.on('room:created', (data) {
      _selfId = data['selfId'];
      _currentSession = GameSessionModel.fromJson(data['room']);
      notifyListeners();
    });

    _socket!.on('room:joined', (data) {
      _selfId = data['selfId'];
      _currentSession = GameSessionModel.fromJson(data['room']);
      notifyListeners();
    });

    _socket!.on('room:updated', (data) {
      _currentSession = GameSessionModel.fromJson(data);
      notifyListeners();
    });

    _socket!.on('game:started', (data) {
      _currentSession = GameSessionModel.fromJson(data['room']);
      _myRole = PlayerRoleExtension.fromString(data['role']);
      _myBleToken = data['bleToken'];
      _isGameOver = false;
      HapticService.tagSuccess();
      notifyListeners();
    });

    _socket!.on('zone:warning', (data) {
      _zoneWarningMessage = data['message'];
      HapticService.alertDangerZone();
      notifyListeners();
    });

    _socket!.on('zone:wave_warning', (data) {
      _waveWarningMessage = data['message'];
      HapticService.alertDangerZone();
      notifyListeners();
    });

    _socket!.on('zone:wave_applied', (data) {
      _waveWarningMessage = null;
      final msg = data['message'] as String?;
      if (msg != null) _gameFeed.insert(0, msg);
      notifyListeners();
    });

    _socket!.on('anticheat:warning', (data) {
      _overspeedWarningMessage = data['message'];
      HapticService.alertOverspeed();
      notifyListeners();
    });

    _socket!.on('player:adrenaline', (data) {
      if (data['points'] != null) {
        _adrenalinePoints = (data['points'] as num).toInt();
      }
      if (data['message'] != null) {
        _cardFeedbackMessage = data['message'];
      }
      notifyListeners();
    });

    _socket!.on('sonar:update', (data) {
      final dist = (data['distanceMeters'] as num?)?.toInt();
      _sonarDistanceMeters = dist;

      if (dist != null) {
        if (dist < 40) {
          HapticService.pulseSonarHot();
        } else if (dist < 90) {
          HapticService.pulseSonarWarm();
        } else {
          HapticService.pulseSonarCold();
        }
      }
      notifyListeners();
    });

    _socket!.on('radar:ping', (data) {
      if (data is List) {
        _radarMicePositions = List<Map<String, dynamic>>.from(data);
        HapticService.pulseSonarWarm();
        notifyListeners();
      }
    });

    _socket!.on('card:success', (data) {
      _cardFeedbackMessage = data['message'];
      HapticService.pulseSonarWarm();
      notifyListeners();
    });

    _socket!.on('card:error', (data) {
      _cardFeedbackMessage = '❌ ' + (data['message'] ?? 'Erreur carte');
      notifyListeners();
    });

    _socket!.on('poi:success', (data) {
      _cardFeedbackMessage = data['message'];
      HapticService.tagSuccess();
      notifyListeners();
    });

    _socket!.on('player:eliminated', (data) {
      _eliminationMessage = data['message'];
      HapticService.alertDangerZone();
      notifyListeners();
    });

    _socket!.on('game:over', (data) {
      _isGameOver = true;
      if (_currentSession != null) {
        _currentSession = GameSessionModel(
          roomCode: _currentSession!.roomCode,
          phase: GamePhase.gameOver,
          hostId: _currentSession!.hostId,
          zoneCenter: _currentSession!.zoneCenter,
          currentRadius: _currentSession!.currentRadius,
          initialRadius: _currentSession!.initialRadius,
          currentWaveIndex: _currentSession!.currentWaveIndex,
          isWarningShrink: false,
          players: _currentSession!.players,
          pois: _currentSession!.pois,
          gameOverData: GameOverDataModel.fromJson(data),
        );
      }
      HapticService.tagSuccess();
      notifyListeners();
    });

    _socket!.on('game:feed', (data) {
      final msg = data['message'] as String?;
      if (msg != null) {
        _gameFeed.insert(0, msg);
        notifyListeners();
      }
    });

    _socket!.connect();
  }

  void createRoom({
    required String nickname,
    required double latitude,
    required double longitude,
    double radius = 800.0,
  }) {
    _socket?.emit('room:create', {
      'nickname': nickname,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    });
  }

  void joinRoom({required String code, required String nickname}) {
    _socket?.emit('room:join', {
      'code': code,
      'nickname': nickname,
    });
  }

  void startGame() {
    _socket?.emit('room:start');
  }

  void sendLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    bool? isMocked,
  }) {
    _socket?.emit('player:location', {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'isMocked': isMocked ?? false,
    });
  }

  void playCard(String cardType) {
    _socket?.emit('card:play', {'cardType': cardType});
  }

  void claimPoi(String poiId) {
    _socket?.emit('poi:claim', {'poiId': poiId});
  }

  void reportBleTag({required String mouseBleToken}) {
    _socket?.emit('ble:tag', {
      'mouseBleToken': mouseBleToken,
    });
    HapticService.tagSuccess();
  }

  void clearCardFeedback() {
    _cardFeedbackMessage = null;
    notifyListeners();
  }

  void clearOverspeedWarning() {
    _overspeedWarningMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}
