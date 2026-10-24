import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../services/location_service.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nicknameController = TextEditingController(text: 'Joueur_1');
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController(text: 'http://10.0.2.2:3000');

  double _selectedRadius = 800; // Rayon par défaut en mètres (Option A)
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationService>().initLocationService();
      context.read<SocketService>().connect(serverUrl: _serverUrlController.text);
    });
  }

  void _onCreateRoom() {
    final loc = context.read<LocationService>().currentPosition;
    final socket = context.read<SocketService>();

    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acquisition du GPS en cours... Veuillez patienter.')),
      );
      return;
    }

    socket.createRoom(
      nickname: _nicknameController.text.trim(),
      latitude: loc.latitude,
      longitude: loc.longitude,
      radius: _selectedRadius,
    );

    _listenForNavigation();
  }

  void _onJoinRoom() {
    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le code de salon doit comporter 6 caractères.')),
      );
      return;
    }

    context.read<SocketService>().joinRoom(
      code: code,
      nickname: _nicknameController.text.trim(),
    );

    _listenForNavigation();
  }

  void _listenForNavigation() {
    final socket = context.read<SocketService>();
    void listener() {
      if (socket.currentSession != null) {
        socket.removeListener(listener);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
      }
    }

    socket.addListener(listener);
  }

  void _showServerUrlDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1E2B),
        title: const Text('Adresse du Serveur 🌐', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Renseignez l\'URL de votre serveur Cloud (Render/Railway) ou Ngrok pour jouer en 4G/5G dans la rue :',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serverUrlController,
              style: const TextStyle(color: Colors.cyanAccent),
              decoration: const InputDecoration(
                hintText: 'https://mon-serveur.onrender.com',
                filled: true,
                fillColor: Color(0xFF12141C),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () {
              context.read<SocketService>().connect(serverUrl: _serverUrlController.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Connecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locService = context.watch<LocationService>();
    final socketService = context.watch<SocketService>();

    return Scaffold(
      backgroundColor: const Color(0xFF12141C),
      appBar: AppBar(
        title: const Text('CAT & MOUSE 🐾', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1B1E2B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.cyanAccent),
            tooltip: 'Configuration Serveur',
            onPressed: _showServerUrlDialog,
          ),
          Icon(
            socketService.isConnected ? Icons.wifi : Icons.wifi_off,
            color: socketService.isConnected ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status GPS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: locService.isReady ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: locService.isReady ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    locService.isReady ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: locService.isReady ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      locService.isReady
                          ? 'GPS Actif (${locService.currentPosition?.latitude.toStringAsFixed(4)}, ${locService.currentPosition?.longitude.toStringAsFixed(4)})'
                          : 'Recherche du signal satellite GPS...',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pseudo
            TextField(
              controller: _nicknameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Votre Pseudo',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF1D2232),
                prefixIcon: const Icon(Icons.person, color: Colors.cyanAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),

            // Mode Création (Option A - Rayon)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E2B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CRÉER UNE NOUVELLE PARTIE',
                    style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Rayon de la zone de jeu : ${_selectedRadius.toInt()} mètres',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _selectedRadius,
                    min: 300,
                    max: 2500,
                    divisions: 22,
                    activeColor: Colors.cyanAccent,
                    inactiveColor: Colors.white24,
                    label: '${_selectedRadius.toInt()} m',
                    onChanged: (val) => setState(() => _selectedRadius = val),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: locService.isReady && socketService.isConnected ? _onCreateRoom : null,
                      child: const Text('CRÉER LE SALON'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Mode Rejoindre
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E2B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REJOINDRE DES POTES',
                    style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _roomCodeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'CODE PIN',
                      hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 2),
                      filled: true,
                      fillColor: const Color(0xFF161924),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: socketService.isConnected ? _onJoinRoom : null,
                      child: const Text('REJOINDRE LA PARTIE'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
