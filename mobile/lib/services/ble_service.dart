import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService extends ChangeNotifier {
  static const String GAME_SERVICE_UUID = '0000FEAA-0000-1000-8000-00805F9B34FB';
  static const int RSSI_PROXIMITY_THRESHOLD = -65; // ~2-3 mètres physiques

  StreamSubscription<List<ScanResult>>? _scanSub;
  String? _detectedMouseToken;
  int _lastDetectedRssi = -100;
  bool _isScanning = false;

  String? get detectedMouseToken => _detectedMouseToken;
  int get lastDetectedRssi => _lastDetectedRssi;
  bool get canTag => _detectedMouseToken != null;

  /// Démarre le scan BLE pour les Chats
  Future<void> startCatScanner() async {
    if (kIsWeb) return;

    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        debugPrint('[BLE] Bluetooth non supporté sur ce terminal.');
        return;
      }

      await FlutterBluePlus.adapterState.where((val) => val == BluetoothAdapterState.on).first;

      _isScanning = true;
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          // On vérifie le niveau RSSI pour la détection < 3m
          if (r.rssi >= RSSI_PROXIMITY_THRESHOLD) {
            // Lecture du token dans les données de service ou nom de device
            final advName = r.advertisementData.advName;
            if (advName.startsWith('CM_')) {
              _detectedMouseToken = advName.replaceFirst('CM_', '');
              _lastDetectedRssi = r.rssi;
              notifyListeners();
              return;
            }
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(minutes: 30),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint('[BLE] Erreur scanner: $e');
    }
  }

  /// Démarre l'émission BLE pour les Souris
  Future<void> startMouseBroadcaster(String bleSessionToken) async {
    // La diffusion d'advertising BLE avec token se configure via FlutterBluePlus ou plugin compagnon
    debugPrint('[BLE] Diffusion active en tant que Souris avec le token: $bleSessionToken');
  }

  /// Simulation manuelle de proximité pour le debug / tests
  void simulateProximityForTesting(String token) {
    _detectedMouseToken = token;
    _lastDetectedRssi = -58;
    notifyListeners();
  }

  void resetTagState() {
    _detectedMouseToken = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    if (_isScanning) {
      FlutterBluePlus.stopScan();
    }
    super.dispose();
  }
}
