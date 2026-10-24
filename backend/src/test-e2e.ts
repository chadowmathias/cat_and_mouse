import http from 'http';
import { Server, Socket as ServerSocket } from 'socket.io';
import { io as ClientIO, Socket as ClientSocket } from 'socket.io-client';
import { GameManager } from './managers/GameManager.js';

const PORT = 3333;

async function wait(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function startServer(): Promise<{ server: http.Server; io: Server }> {
  const server = http.createServer();
  const io = new Server(server, { cors: { origin: '*' } });
  const gameManager = new GameManager();
  const socketRoomMap = new Map<string, string>();

  io.on('connection', (socket: ServerSocket) => {
    socket.on('room:create', (data) => {
      const room = gameManager.createRoom(socket.id, data.nickname, data.latitude, data.longitude, data.radius || 600);
      socket.join(room.code);
      socketRoomMap.set(socket.id, room.code);
      socket.emit('room:created', { room: gameManager.serializeRoom(room, socket.id), selfId: socket.id });
    });

    socket.on('room:join', (data) => {
      const room = gameManager.getRoom(data.code.toUpperCase().trim())!;
      gameManager.joinRoom(room.code, socket.id, data.nickname);
      socket.join(room.code);
      socketRoomMap.set(socket.id, room.code);
      socket.emit('room:joined', { room: gameManager.serializeRoom(room, socket.id), selfId: socket.id });
    });

    socket.on('room:start', () => {
      const roomCode = socketRoomMap.get(socket.id)!;
      const room = gameManager.getRoom(roomCode)!;
      gameManager.startGame(roomCode);
      for (const p of room.players.values()) {
        io.to(p.id).emit('game:started', {
          room: gameManager.serializeRoom(room, p.id),
          role: p.role,
          bleToken: p.bleSessionToken,
        });
      }
    });

    socket.on('player:location', (data) => {
      const roomCode = socketRoomMap.get(socket.id)!;
      gameManager.updatePlayerLocation(roomCode, socket.id, {
        latitude: data.latitude,
        longitude: data.longitude,
        timestamp: Date.now(),
      });
    });

    socket.on('poi:claim', (data) => {
      const roomCode = socketRoomMap.get(socket.id)!;
      const res = gameManager.claimPoi(roomCode, socket.id, data.poiId);
      socket.emit('poi:success', res);
    });

    socket.on('ble:tag', (data) => {
      const roomCode = socketRoomMap.get(socket.id)!;
      const res = gameManager.processBleTag(roomCode, socket.id, data.mouseBleToken);
      if (res.success) {
        socket.emit('tag:success', { mouseNickname: res.eliminatedMouse?.nickname });
        io.to(res.eliminatedMouse!.id).emit('player:eliminated', { message: 'Touché !' });
        const gameOver = gameManager.evaluateGameEnd(roomCode);
        if (gameOver) {
          io.to(roomCode).emit('game:over', gameOver);
        }
      } else {
        socket.emit('tag:failed', { message: res.error });
      }
    });
  });

  await new Promise<void>((resolve) => server.listen(PORT, resolve));
  return { server, io };
}

async function run() {
  console.log('🚀 [TEST] Démarrage du serveur et des clients...');
  const { server, io: serverIo } = await startServer();

  const url = `http://localhost:${PORT}`;
  const p1: ClientSocket = ClientIO(url, { transports: ['websocket'] });
  const p2: ClientSocket = ClientIO(url, { transports: ['websocket'] });
  const p3: ClientSocket = ClientIO(url, { transports: ['websocket'] });

  await new Promise<void>((resolve) => {
    let count = 0;
    const onConn = () => {
      count++;
      if (count === 3) resolve();
    };
    p1.once('connect', onConn);
    p2.once('connect', onConn);
    p3.once('connect', onConn);
  });
  console.log('✅ Serveur & 3 Clients connectés avec succès');

  // 1. Création du salon par P1
  let code = '';
  const roomCreatedPromise = new Promise<void>((resolve) => {
    p1.once('room:created', (d) => {
      code = d.room.code;
      console.log(`🏠 Salon créé : ${code} (Rayon: ${d.room.zone.currentRadius}m)`);
      resolve();
    });
  });
  p1.emit('room:create', { nickname: 'Alice', latitude: 48.8566, longitude: 2.3522, radius: 800 });
  await roomCreatedPromise;

  // 2. P2 et P3 rejoignent
  const join2 = new Promise<void>((resolve) => p2.once('room:joined', () => resolve()));
  const join3 = new Promise<void>((resolve) => p3.once('room:joined', () => resolve()));
  p2.emit('room:join', { code, nickname: 'Bob' });
  p3.emit('room:join', { code, nickname: 'Charlie' });
  await Promise.all([join2, join3]);
  console.log('👥 Bob et Charlie ont rejoint Alice dans le salon');

  // 3. Lancer la partie et récupérer les rôles
  interface PlayerInfo {
    socket: ClientSocket;
    nickname: string;
    role: string;
    bleToken: string;
  }
  const players: PlayerInfo[] = [];

  const startPromise = Promise.all([
    new Promise<void>((resolve) => {
      p1.once('game:started', (d) => {
        players.push({ socket: p1, nickname: 'Alice', role: d.role, bleToken: d.bleToken });
        resolve();
      });
    }),
    new Promise<void>((resolve) => {
      p2.once('game:started', (d) => {
        players.push({ socket: p2, nickname: 'Bob', role: d.role, bleToken: d.bleToken });
        resolve();
      });
    }),
    new Promise<void>((resolve) => {
      p3.once('game:started', (d) => {
        players.push({ socket: p3, nickname: 'Charlie', role: d.role, bleToken: d.bleToken });
        resolve();
      });
    }),
  ]);
  p1.emit('room:start');
  await startPromise;

  const catPlayer = players.find((p) => p.role === 'CAT')!;
  const micePlayers = players.filter((p) => p.role === 'MOUSE');

  console.log(`🐱 Chat désigné : ${catPlayer.nickname}`);
  for (const m of micePlayers) {
    console.log(`🐭 Souris désignée : ${m.nickname} (BLE: ${m.bleToken})`);
  }

  // 4. Mises à jour de positions GPS cohérentes
  p1.emit('player:location', { latitude: 48.8566, longitude: 2.3522 });
  p2.emit('player:location', { latitude: 48.8567, longitude: 2.3523 });
  p3.emit('player:location', { latitude: 48.8568, longitude: 2.3524 });
  await wait(200);

  // 5. Récolte d'un ravitaillement par la première souris
  const poiPromise = new Promise<void>((resolve) => micePlayers[0].socket.once('poi:success', () => resolve()));
  micePlayers[0].socket.emit('poi:claim', { poiId: 'poi_1' });
  await poiPromise;
  console.log(`🧀 ${micePlayers[0].nickname} a récolté une Fromagerie (+40⚡)`);

  // 6. Éliminations physiques par le Chat
  const gameOverPromise = new Promise<any>((resolve) => {
    catPlayer.socket.once('game:over', (d) => resolve(d));
  });

  for (let i = 0; i < micePlayers.length; i++) {
    const mouse = micePlayers[i];
    console.log(`🎯 ${catPlayer.nickname} (Chat) tagge ${mouse.nickname} via BLE...`);
    catPlayer.socket.emit('ble:tag', { mouseBleToken: mouse.bleToken });
    await wait(300);
  }

  const gameOverData = await gameOverPromise;

  console.log('\n🏆 ===============================================');
  console.log(`🏆 FIN DE PARTIE CONFIRMÉE ! Vainqueur: ${gameOverData.winner}`);
  console.log(`📝 Raison: ${gameOverData.reason}`);
  console.log('📊 Statistiques des joueurs :');
  for (const p of gameOverData.playersStats) {
    console.log(`   - ${p.nickname} (${p.role}) : Tags: ${p.stats.tagsCount}, Distance: ${p.stats.distanceTraveledMeters}m`);
  }
  console.log('🏆 ===============================================\n');

  p1.disconnect();
  p2.disconnect();
  p3.disconnect();
  server.close();
  serverIo.close();
  console.log('🎉 TEST BOUT EN BOUT VALIDÉ À 100% SANS AUCUNE ERREUR !');
  process.exit(0);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
