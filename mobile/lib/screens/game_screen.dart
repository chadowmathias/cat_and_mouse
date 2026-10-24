import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';
import '../services/ble_service.dart';
import '../services/haptic_service.dart';
import '../services/audio_service.dart';
import '../models/player.dart';
import '../models/game_session.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final MapController _mapController = MapController();
  Timer? _locationSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = context.read<SocketService>();
      final ble = context.read<BleService>();

      if (socket.myRole == PlayerRole.cat) {
        ble.startCatScanner();
      } else if (socket.myRole == PlayerRole.mouse && socket.myBleToken != null) {
        ble.startMouseBroadcaster(socket.myBleToken!);
      }

      // Synchronisation GPS continue toutes les 2.5 secondes avec détection faux GPS
      _locationSyncTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        final loc = context.read<LocationService>();
        final pos = loc.currentPosition;
        if (pos != null) {
          socket.sendLocation(
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: pos.accuracy,
            isMocked: loc.isMocked,
          );
        }
      });

      // Écoute de fin de partie
      socket.addListener(_checkGameOver);
    });
  }

  void _checkGameOver() {
    final socket = context.read<SocketService>();
    if (socket.isGameOver && mounted) {
      socket.removeListener(_checkGameOver);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameOverScreen()),
      );
    }
  }

  @override
  void dispose() {
    _locationSyncTimer?.cancel();
    context.read<AudioService>().stopHeartbeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final locService = context.watch<LocationService>();
    final bleService = context.watch<BleService>();
    final session = socket.currentSession;

    final myCoord = locService.currentPosition != null
        ? LatLng(locService.currentPosition!.latitude, locService.currentPosition!.longitude)
        : session?.zoneCenter ?? const LatLng(48.8566, 2.3522);

    final isCat = socket.myRole == PlayerRole.cat;
    final isInside = session != null
        ? locService.isInsideZone(session.zoneCenter, session.currentRadius)
        : true;

    return Scaffold(
      backgroundColor: const Color(0xFF12141C),
      body: Stack(
        children: [
          // 1. CARTE OPENSTREETMAP INTERACTIVE
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: myCoord,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.game.cat_and_mouse',
              ),

              // Cercles de Zone Battle Royale
              if (session != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: session.zoneCenter,
                      radius: session.currentRadius,
                      useRadiusInMeter: true,
                      color: isInside ? Colors.green.withOpacity(0.10) : Colors.red.withOpacity(0.25),
                      borderColor: isInside ? Colors.greenAccent : Colors.redAccent,
                      borderStrokeWidth: 3,
                    ),
                    if (session.isWarningShrink && session.targetRadius != null)
                      CircleMarker(
                        point: session.zoneCenter,
                        radius: session.targetRadius!,
                        useRadiusInMeter: true,
                        color: Colors.orangeAccent.withOpacity(0.15),
                        borderColor: Colors.orangeAccent,
                        borderStrokeWidth: 2,
                      ),
                  ],
                ),

              // Marqueurs
              MarkerLayer(
                markers: [
                  Marker(
                    point: myCoord,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCat ? Colors.redAccent : Colors.cyanAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isCat ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(isCat ? '🐱' : '🐭', style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),

                  if (session != null)
                    ...session.pois.map(
                      (poi) => Marker(
                        point: poi.position,
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => socket.claimPoi(poi.id),
                          child: Container(
                            decoration: BoxDecoration(
                              color: poi.isAvailable ? Colors.amberAccent : Colors.grey.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                if (poi.isAvailable)
                                  const BoxShadow(color: Colors.amber, blurRadius: 8, spreadRadius: 2),
                              ],
                            ),
                            child: const Center(child: Text('🧀', style: TextStyle(fontSize: 20))),
                          ),
                        ),
                      ),
                    ),

                  if (isCat)
                    ...socket.radarMicePositions.map(
                      (m) => Marker(
                        point: LatLng(
                          (m['latitude'] as num).toDouble(),
                          (m['longitude'] as num).toDouble(),
                        ),
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.85),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              m['isDecoy'] == true ? '🎭' : '📍',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. HUD SUPÉRIEUR (Alertes, Anti-Triche, Sonar)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // Alerte Anti-Triche Vitesse Véhicule (Option A)
                  if (socket.overspeedWarningMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade900,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purpleAccent, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.purpleAccent, blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_bike, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              socket.overspeedWarningMessage!,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Alerte Hors de Zone
                  if (!isInside)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.red, blurRadius: 10)],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚠️ HORS ZONE ! Réintégrez le cercle sous 45s ou élimination !',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Alerte Vague Battle Royale
                  if (socket.waveWarningMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade900,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.orange, blurRadius: 8)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              socket.waveWarningMessage!,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Jauge Haptique Sonar (Chat)
                  if (isCat && socket.sonarDistanceMeters != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: socket.sonarDistanceMeters! < 40
                            ? Colors.red.shade800
                            : socket.sonarDistanceMeters! < 90
                                ? Colors.orange.shade800
                                : Colors.blue.shade900,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: socket.sonarDistanceMeters! < 40 ? Colors.redAccent : Colors.cyanAccent,
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📡', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            socket.sonarDistanceMeters! < 40
                                ? '💥 BRÛLANT ! Souris à ~${socket.sonarDistanceMeters}m (Vibrations MAX) !'
                                : 'SONAR : Souris la plus proche à ~${socket.sonarDistanceMeters}m',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                  // Bandeau d'état & Adrénaline
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1E2B).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCat ? Colors.redAccent.withOpacity(0.2) : Colors.cyanAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isCat ? Colors.redAccent : Colors.cyanAccent),
                          ),
                          child: Text(
                            socket.myRole.displayName,
                            style: TextStyle(
                              color: isCat ? Colors.redAccent : Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Text(
                              '${socket.adrenalinePoints} pts',
                              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        Text(
                          'Vague ${session?.currentWaveIndex ?? 1}',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  if (socket.cardFeedbackMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: GestureDetector(
                        onTap: socket.clearCardFeedback,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E3856),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.cyanAccent.withOpacity(0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  socket.cardFeedbackMessage!,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.close, size: 14, color: Colors.white60),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. BARRE INFÉRIEURE : CARTES & TAG BLE
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1E2B).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (!isCat) ...[
                        _buildCardButton(
                          title: 'Invisibilité',
                          emoji: '👻',
                          cost: 40,
                          currentPoints: socket.adrenalinePoints,
                          onTap: () => socket.playCard('INVISIBILITY'),
                        ),
                        _buildCardButton(
                          title: 'Leurre 150m',
                          emoji: '🎭',
                          cost: 30,
                          currentPoints: socket.adrenalinePoints,
                          onTap: () => socket.playCard('DECOY'),
                        ),
                      ],
                      if (isCat) ...[
                        _buildCardButton(
                          title: 'Sonar 45s',
                          emoji: '📡',
                          cost: 45,
                          currentPoints: socket.adrenalinePoints,
                          onTap: () => socket.playCard('SONAR'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                if (isCat) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(backgroundColor: Colors.black54),
                        onPressed: () {
                          bleService.simulateProximityForTesting('TEST_TOKEN');
                          HapticService.pulseSonarHot();
                        },
                        icon: const Icon(Icons.bug_report, size: 14, color: Colors.orangeAccent),
                        label: const Text('Simuler BLE < 3m', style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: bleService.canTag ? Colors.redAccent : Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        elevation: bleService.canTag ? 10 : 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: bleService.canTag
                          ? () {
                              socket.reportBleTag(mouseBleToken: bleService.detectedMouseToken!);
                              bleService.resetTagState();
                            }
                          : null,
                      child: Text(
                        bleService.canTag ? '💥 ATTRAPÉ ! (TOUCHER POUR ÉLIMINER)' : '🔍 Recherche BLE de Souris...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 4. ÉCRAN D'ÉLIMINATION
          if (socket.eliminationMessage != null)
            Container(
              color: Colors.black.withOpacity(0.9),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 80),
                      const SizedBox(height: 20),
                      const Text(
                        'VOUS ÊTES ÉLIMINÉ !',
                        style: TextStyle(color: Colors.redAccent, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        socket.eliminationMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardButton({
    required String title,
    required String emoji,
    required int cost,
    required int currentPoints,
    required VoidCallback onTap,
  }) {
    final canAfford = currentPoints >= cost;

    return InkWell(
      onTap: canAfford ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: canAfford ? const Color(0xFF262D42) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: canAfford ? Colors.cyanAccent.withOpacity(0.5) : Colors.white10),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: canAfford ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('$cost ⚡', style: TextStyle(color: canAfford ? Colors.amberAccent : Colors.white24, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
