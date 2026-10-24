import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';
import '../models/player.dart';
import 'home_screen.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final gameOverData = socket.currentSession?.gameOverData;
    final winner = gameOverData?.winner ?? 'CATS';
    final isCat = socket.myRole == PlayerRole.cat;
    final hasWon = (winner == 'CATS' && isCat) || (winner == 'MICE' && !isCat);

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // Bannière de Victoire / Défaite
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: hasWon ? Colors.amber.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: hasWon ? Colors.amberAccent : Colors.redAccent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      hasWon ? '🏆' : '💀',
                      style: const TextStyle(fontSize: 60),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasWon ? 'VICTOIRE !' : 'DÉFAITE...',
                      style: TextStyle(
                        color: hasWon ? Colors.amberAccent : Colors.redAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      winner == 'CATS' ? 'Les Chats ont raflé toutes les Souris !' : 'Les Souris ont survécu au temps réglementaire !',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Titre Tableau des scores
              const Text(
                'TABLEAU D\'HONNEUR & STATS',
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),

              // Liste des joueurs et stats
              Expanded(
                child: ListView.separated(
                  itemCount: gameOverData?.playersStats.length ?? 0,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = gameOverData!.playersStats[index];
                    final isMe = p.id == socket.selfId;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF1E2538) : const Color(0xFF161925),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isMe ? Colors.cyanAccent : Colors.white10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: p.role == PlayerRole.cat ? Colors.redAccent : Colors.cyanAccent,
                            radius: 20,
                            child: Text(p.role == PlayerRole.cat ? '🐱' : '🐭', style: const TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      p.nickname + (isMe ? ' (Vous)' : ''),
                                      style: TextStyle(
                                        color: isMe ? Colors.cyanAccent : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (p.isAlive)
                                      const Text('👑 Survivant', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    Text('🏃 ${p.stats.distanceTraveledMeters}m', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                    if (p.role == PlayerRole.cat)
                                      Text('🎯 ${p.stats.tagsCount} touché(s)', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))
                                    else
                                      Text('⏱️ ${p.stats.timeSurvivedSeconds}s survécues', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Bouton Rejouer
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('RETOUR AU MENU PRINCIPAL'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
