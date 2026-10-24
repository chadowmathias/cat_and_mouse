import http from 'http';
import { Server, Socket } from 'socket.io';
import { GameManager } from './managers/GameManager.js';
import { CardType } from './types/game.js';

const PORT = process.env.PORT || 3000;
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ status: 'ok', name: 'Cat & Mouse Backend' }));
});

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

const gameManager = new GameManager();
const socketRoomMap = new Map<string, string>();

io.on('connection', (socket: Socket) => {
  console.log(`[Connect] Joueur connecté: ${socket.id}`);

  socket.on('room:create', (data: { nickname: string; latitude: number; longitude: number; radius?: number }) => {
    try {
      const room = gameManager.createRoom(
        socket.id,
        data.nickname || 'Hôte',
        data.latitude,
        data.longitude,
        data.radius || 800
      );

      socket.join(room.code);
      socketRoomMap.set(socket.id, room.code);

      socket.emit('room:created', {
        room: gameManager.serializeRoom(room, socket.id),
        selfId: socket.id,
      });
    } catch (err: any) {
      socket.emit('error', { message: err.message });
    }
  });

  socket.on('room:join', (data: { code: string; nickname: string }) => {
    try {
      const roomCode = data.code.toUpperCase().trim();
      const player = gameManager.joinRoom(roomCode, socket.id, data.nickname);

      if (!player) {
        return socket.emit('error', { message: 'Code de salon invalide ou partie déjà commencée.' });
      }

      socket.join(roomCode);
      socketRoomMap.set(socket.id, roomCode);

      const room = gameManager.getRoom(roomCode)!;
      socket.emit('room:joined', {
        room: gameManager.serializeRoom(room, socket.id),
        selfId: socket.id,
      });

      for (const p of room.players.values()) {
        io.to(p.id).emit('room:updated', gameManager.serializeRoom(room, p.id));
      }
    } catch (err: any) {
      socket.emit('error', { message: err.message });
    }
  });

  socket.on('room:start', () => {
    const roomCode = socketRoomMap.get(socket.id);
    if (!roomCode) return;

    const room = gameManager.getRoom(roomCode);
    if (!room || room.hostId !== socket.id) {
      return socket.emit('error', { message: 'Seul l’hôte peut lancer la partie.' });
    }

    const result = gameManager.startGame(roomCode);
    if (!result.success) {
      return socket.emit('error', { message: result.error });
    }

    for (const p of room.players.values()) {
      io.to(p.id).emit('game:started', {
        room: gameManager.serializeRoom(room, p.id),
        role: p.role,
        bleToken: p.bleSessionToken,
      });
    }
  });

  // Mise à jour GPS
  socket.on('player:location', (data: { latitude: number; longitude: number; accuracy?: number; isMocked?: boolean }) => {
    const roomCode = socketRoomMap.get(socket.id);
    if (!roomCode) return;

    const res = gameManager.updatePlayerLocation(roomCode, socket.id, {
      latitude: data.latitude,
      longitude: data.longitude,
      accuracy: data.accuracy,
      isMocked: data.isMocked,
      timestamp: Date.now(),
    });

    if (res.cheatAlert) {
      if (res.cheatAlert.type === 'MOCK_GPS') {
        socket.emit('player:eliminated', {
          message: '🚫 ÉLIMINÉ : Faux GPS (Mock Location) détecté.',
        });
        io.to(roomCode).emit('game:feed', {
          type: 'ELIMINATION',
          message: `🚫 ${res.player?.nickname} a été banni pour faux GPS !`,
        });
        _checkAndEmitGameOver(roomCode);
        return;
      }

      if (res.cheatAlert.type === 'OVERSPEED_WARNING') {
        socket.emit('anticheat:warning', {
          message: `🚨 VITESSE ANORMALE (${res.cheatAlert.speedKmh} km/h) ! Ralentissez sous 10s ou élimination !`,
          speedKmh: res.cheatAlert.speedKmh,
        });
      }

      if (res.cheatAlert.type === 'OVERSPEED_ELIMINATED') {
        socket.emit('player:eliminated', {
          message: '🚴 ÉLIMINÉ : Utilisation de véhicule détectée (> 25 km/h pendant plus de 10s).',
        });
        io.to(roomCode).emit('game:feed', {
          type: 'ELIMINATION',
          message: `🚴 ${res.player?.nickname} a été éliminé pour usage de véhicule !`,
        });
        _checkAndEmitGameOver(roomCode);
        return;
      }
    }

    if (!res.isInside) {
      socket.emit('zone:warning', {
        message: '⚠️ VOUS ÊTES HORS DE LA ZONE ! Revenez immédiatement.',
        outOfZoneSince: res.outOfZoneSince,
      });
    }

    if (res.proximityBonus) {
      socket.emit('player:adrenaline', {
        points: res.player?.adrenalinePoints,
        message: '⚡ Risque payant : +2 Adrénaline (proximité du Chat !)',
      });
    }
  });

  socket.on('card:play', (data: { cardType: CardType }) => {
    const roomCode = socketRoomMap.get(socket.id);
    if (!roomCode) return;

    const result = gameManager.playCard(roomCode, socket.id, data.cardType);
    if (!result.success) {
      return socket.emit('card:error', { message: result.error });
    }

    socket.emit('card:success', {
      cardType: data.cardType,
      message: result.message,
    });

    const room = gameManager.getRoom(roomCode);
    const player = room?.players.get(socket.id);
    if (player) {
      socket.emit('player:adrenaline', { points: player.adrenalinePoints });
    }

    io.to(roomCode).emit('game:feed', {
      type: 'CARD',
      message: `✨ Une carte spéciale vient d'être activée dans la zone !`,
    });
  });

  socket.on('poi:claim', (data: { poiId: string }) => {
    const roomCode = socketRoomMap.get(socket.id);
    if (!roomCode) return;

    const res = gameManager.claimPoi(roomCode, socket.id, data.poiId);
    if (!res.success) {
      return socket.emit('poi:error', { message: res.error });
    }

    socket.emit('poi:success', {
      message: `🧀 Ravitaillement validé ! +${res.reward} Adrénaline`,
      reward: res.reward,
    });

    const room = gameManager.getRoom(roomCode);
    if (room) {
      const p = room.players.get(socket.id);
      if (p) socket.emit('player:adrenaline', { points: p.adrenalinePoints });
      for (const pl of room.players.values()) {
        io.to(pl.id).emit('room:updated', gameManager.serializeRoom(room, pl.id));
      }
    }
  });

  // Tag BLE
  socket.on('ble:tag', (data: { mouseBleToken: string }) => {
    const roomCode = socketRoomMap.get(socket.id);
    if (!roomCode) return;

    const result = gameManager.processBleTag(roomCode, socket.id, data.mouseBleToken);
    if (!result.success) {
      return socket.emit('tag:failed', { message: result.error });
    }

    socket.emit('tag:success', { mouseNickname: result.eliminatedMouse?.nickname });

    io.to(result.eliminatedMouse!.id).emit('player:eliminated', {
      by: socket.id,
      message: 'Vous avez été touché par un Chat ! Vous êtes éliminé.',
    });

    io.to(roomCode).emit('game:feed', {
      type: 'ELIMINATION',
      message: `🎯 ${result.eliminatedMouse?.nickname} a été attrapé(e) !`,
    });

    _checkAndEmitGameOver(roomCode);
  });

  socket.on('disconnect', () => {
    const res = gameManager.removePlayer(socket.id);
    if (res) {
      const { roomCode, room } = res;
      for (const p of room.players.values()) {
        io.to(p.id).emit('room:updated', gameManager.serializeRoom(room, p.id));
      }
    }
    socketRoomMap.delete(socket.id);
  });
});

function _checkAndEmitGameOver(roomCode: string) {
  const gameOverData = gameManager.evaluateGameEnd(roomCode);
  if (gameOverData) {
    io.to(roomCode).emit('game:over', gameOverData);
    console.log(`[GameOver] Fin de partie dans ${roomCode} ! Vainqueur: ${gameOverData.winner}`);
  }
}

// Boucle principale de tick serveur (2s)
setInterval(() => {
  const now = Date.now();
  const rooms = gameManager.getAllRooms();

  for (const [code, room] of rooms.entries()) {
    if (room.status === 'LOBBY' || room.status === 'FINISHED') continue;

    // Vérifier fin de partie globale
    const gameOver = gameManager.evaluateGameEnd(code);
    if (gameOver) {
      io.to(code).emit('game:over', gameOver);
      continue;
    }

    if (room.status === 'HEAD_START' && room.headStartEndsAt && now >= room.headStartEndsAt) {
      room.status = 'HUNTING';
      io.to(code).emit('game:phase_changed', {
        status: 'HUNTING',
        message: '🚨 LES 5 MINUTES SONT ÉCOULÉES : LES CHATS SONT LÂCHÉS !',
      });
    }

    const zone = room.zone;
    if (room.status === 'HUNTING' && zone.nextWaveStartsAt) {
      if (!zone.isWarningShrink && now >= zone.nextWaveStartsAt - 90 * 1000) {
        zone.isWarningShrink = true;
        zone.targetRadius = Math.round(zone.currentRadius * 0.65);
        zone.shrinkWarningEndsAt = zone.nextWaveStartsAt;

        io.to(code).emit('zone:wave_warning', {
          targetRadius: zone.targetRadius,
          warningSeconds: 90,
          message: `⚠️ ATTENTION : La zone se réduit à ${zone.targetRadius}m dans 90 secondes ! Rejoignez le centre !`,
        });
      }

      if (zone.isWarningShrink && now >= zone.nextWaveStartsAt) {
        zone.isWarningShrink = false;
        zone.currentRadius = zone.targetRadius || Math.round(zone.currentRadius * 0.65);
        zone.currentWaveIndex += 1;

        if (zone.currentWaveIndex < 3) {
          zone.nextWaveStartsAt = now + 6 * 60 * 1000;
        } else {
          zone.nextWaveStartsAt = undefined;
        }

        io.to(code).emit('zone:wave_applied', {
          currentRadius: zone.currentRadius,
          waveIndex: zone.currentWaveIndex,
          message: `⚡ LA ZONE S'EST RÉDUITE ! Nouveau rayon : ${zone.currentRadius}m`,
        });
      }
    }

    if (room.status === 'HUNTING') {
      if (!room.nextRadarPingAt || now >= room.nextRadarPingAt) {
        const blips = gameManager.generateRadarPingForCats(code);
        for (const p of room.players.values()) {
          if (p.role === 'CAT') {
            io.to(p.id).emit('radar:ping', blips);
          }
        }

        const interval = zone.currentWaveIndex >= 3 ? 60 * 1000 : room.radarIntervalMs;
        room.nextRadarPingAt = now + interval;
        io.to(code).emit('radar:scheduled', { nextRadarPingAt: room.nextRadarPingAt });
      }
    }

    for (const p of room.players.values()) {
      if (p.role === 'CAT' && p.activeEffects.isSonarActiveUntil && p.activeEffects.isSonarActiveUntil > now) {
        const dist = gameManager.getSonarDistanceForCat(code, p.id);
        if (dist !== null) {
          io.to(p.id).emit('sonar:update', { distanceMeters: dist });
        }
      }
    }

    // Contrôle 45s hors-zone
    for (const p of room.players.values()) {
      if (p.isAlive && p.outOfZoneSince && now - p.outOfZoneSince > 45 * 1000) {
        p.isAlive = false;
        io.to(p.id).emit('player:eliminated', {
          message: 'ÉLIMINÉ : 45 secondes consécutives hors-zone !',
        });
        io.to(code).emit('game:feed', {
          type: 'ELIMINATION',
          message: `💀 ${p.nickname} a été éliminé(e) pour désertion hors-zone !`,
        });
        _checkAndEmitGameOver(code);
      }
    }
  }
}, 2000);

server.listen(PORT, () => {
  console.log(`===============================================`);
  console.log(`🚀 CAT & MOUSE SERVER en écoute sur le port ${PORT}`);
  console.log(`📡 WebSocket Gateway prête (Sprint 4 : Fin de partie & Stats)`);
  console.log(`===============================================`);
});
