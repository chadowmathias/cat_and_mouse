import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService extends ChangeNotifier {
  final AudioPlayer _effectsPlayer = AudioPlayer();
  final AudioPlayer _heartbeatPlayer = AudioPlayer();

  bool _isHeartbeatPlaying = false;
  int _currentHeartbeatBpm = 60;
  Timer? _heartbeatTimer;

  bool get isHeartbeatPlaying => _isHeartbeatPlaying;
  int get currentHeartbeatBpm => _currentHeartbeatBpm;

  AudioService() {
    _effectsPlayer.setReleaseMode(ReleaseMode.stop);
    _heartbeatPlayer.setReleaseMode(ReleaseMode.stop);
  }

  /// Joue la sirène d'alerte lors du rétrécissement de la zone (Battle Royale)
  Future<void> playZoneSiren() async {
    try {
      // Source audio en ligne fiable ou asset local
      await _effectsPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'),
        volume: 0.8,
      );
    } catch (e) {
      debugPrint('[Audio] Erreur sirène: $e');
    }
  }

  /// Joue le son de confirmation d'élimination / Tag
  Future<void> playEliminationSound() async {
    try {
      await _effectsPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2874/2874-preview.mp3'),
        volume: 0.9,
      );
    } catch (e) {
      debugPrint('[Audio] Erreur élimination: $e');
    }
  }

  /// Joue le son futuriste de déclenchement de carte de pouvoir
  Future<void> playPowerUpSound() async {
    try {
      await _effectsPlayer.play(
        UrlSource('https://assets.mixkit.co/active_storage/sfx/2019/2019-preview.mp3'),
        volume: 0.7,
      );
    } catch (e) {
      debugPrint('[Audio] Erreur powerup: $e');
    }
  }

  /// Met à jour la fréquence du battement de cœur selon la distance du Chat
  void updateHeartbeatForDistance(int? distanceMeters) {
    if (distanceMeters == null || distanceMeters > 120) {
      stopHeartbeat();
      return;
    }

    int targetBpm;
    if (distanceMeters < 35) {
      targetBpm = 145; // Panique totale : Chat à moins de 35 mètres
    } else if (distanceMeters < 75) {
      targetBpm = 100; // Tension élevée
    } else {
      targetBpm = 65;  // Prémices du danger
    }

    if (!_isHeartbeatPlaying || _currentHeartbeatBpm != targetBpm) {
      _currentHeartbeatBpm = targetBpm;
      _startHeartbeatLoop();
    }
  }

  void _startHeartbeatLoop() {
    _heartbeatTimer?.cancel();
    _isHeartbeatPlaying = true;
    notifyListeners();

    final intervalMs = (60000 / _currentHeartbeatBpm).round();

    _heartbeatTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) async {
      try {
        await _heartbeatPlayer.play(
          UrlSource('https://assets.mixkit.co/active_storage/sfx/2408/2408-preview.mp3'),
          volume: _currentHeartbeatBpm > 120 ? 1.0 : 0.5,
        );
      } catch (e) {
        debugPrint('[Audio] Erreur battement: $e');
      }
    });
  }

  void stopHeartbeat() {
    if (_isHeartbeatPlaying) {
      _heartbeatTimer?.cancel();
      _isHeartbeatPlaying = false;
      _heartbeatPlayer.stop();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _effectsPlayer.dispose();
    _heartbeatPlayer.dispose();
    super.dispose();
  }
}
