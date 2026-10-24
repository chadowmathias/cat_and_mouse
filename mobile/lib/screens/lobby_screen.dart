import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../models/game_session.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = context.read<SocketService>();
      socket.addListener(_checkGameStarted);
    });
  }

  void _checkGameStarted() {
    final socket = context.read<SocketService>();
    if (socket.currentSession?.phase != GamePhase.lobby) {
      socket.removeListener(_checkGameStarted);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final session = socket.currentSession;

    if (session == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF12141C),
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF12141C),
      appBar: AppBar(
        title: const Text('SALON D\'ATTENTE', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1B1E2B),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Code PIN
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D2232),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent, width: 2),
              ),
              child: Column(
                children: [
                  const Text('CODE DE LA PARTIE', style: TextStyle(color: Colors.white60, fontSize: 13, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text(
                    session.roomCode,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Zone : ${session.currentRadius.toInt()}m de rayon',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Titre Joueurs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'JOUEURS PRÊTS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${session.players.length} connecté(s)',
                  style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Liste des joueurs
            Expanded(
              child: ListView.separated(
                itemCount: session.players.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final player = session.players[index];
                  final isMe = player.id == socket.selfId;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF262D42) : const Color(0xFF1B1E2B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isMe ? Colors.cyanAccent : Colors.white12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: player.isHost ? Colors.amberAccent : Colors.blueGrey,
                          radius: 16,
                          child: Icon(
                            player.isHost ? Icons.star : Icons.person,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            player.nickname + (isMe ? ' (Vous)' : ''),
                            style: TextStyle(
                              color: isMe ? Colors.cyanAccent : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (player.isHost)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amberAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('HÔTE', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Bouton de lancement
            if (socket.isHost)
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: session.players.length >= 2 ? Colors.greenAccent : Colors.grey.shade800,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: session.players.length >= 2 ? socket.startGame : null,
                  child: Text(
                    session.players.length >= 2 ? 'LANCER LA PARTIE 🚀' : 'En attente de 2 joueurs min...',
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)),
                    SizedBox(width: 12),
                    Text('L\'hôte va bientôt lancer la partie...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
