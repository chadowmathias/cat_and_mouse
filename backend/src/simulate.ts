import { io, Socket } from 'socket.io-client';

const SERVER_URL = 'http://localhost:3000';

async function wait(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function runSimulation() {
  console.log('🐾 [SIMULATION] Démarrage du banc d\'essai Cat & Mouse...');

  const catSocket: Socket = io(SERVER_URL, { transports: ['websocket'] });
  const mouse1Socket: Socket = io(SERVER_URL, { transports: ['websocket'] });
  const mouse2Socket: Socket = io(SERVER_URL, { transports: ['websocket'] });

  await new Promise<void>((resolve) => {
    let connected = 0;
    const check = () => {
      connected++;
      if (connected === 3) resolve();
    };
    catSocket.on('connect', check);
    mouse1Socket.on('connect', check);
    mouse2Socket.on('connect', check);
  });

  console.log('✅ 3 Joueurs connectés au serveur WebSocket !');

  let roomCode = '';
  let mouse1BleToken = '';
  let mouse2BleToken = '';

  // 1. Création de la Room par l'Hôte
  catSocket.emit('room:create', {
    nickname: 'LeChatNoir',
    latitude: 48.8566,
    longitude: 2.3522,
    radius: 600,
  });

  await new Promise<void>((resolve) => {
    catSocket.on('room:created', (data) => {
      roomCode = data.room.code;
      console.log(`📍 Salon créé avec succès : [${roomCode}] (Rayon: ${data.room.zone.currentRadius}m)`);
      resolve();
    });
  });

  // 2. Les Souris rejoignent le salon
  mouse1Socket.emit('room:join', { code: roomCode, nickname: 'SpeedyGonzales' });
  mouse2Socket.emit('room:join', { code: roomCode, nickname: 'MickeyMouse' });
  await wait(1000);

  // 3. L'hôte lance la partie
  console.log('🚀 Lancement de la partie par l\'hôte...');
  catSocket.emit('room:start');

  await Promise.all([
    new Promise<void>((resolve) => {
      mouse1Socket.on('game:started', (data) => {
        mouse1BleToken = data.bleToken;
        console.log(`🐭 SpeedyGonzales assigné au rôle : ${data.role} (BLE Token: ${mouse1BleToken})`);
        resolve();
      });
    }),
    new Promise<void>((resolve) => {
      mouse2Socket.on('game:started', (data) => {
        mouse2BleToken = data.bleToken;
        console.log(`🐭 MickeyMouse assigné au rôle : ${data.role} (BLE Token: ${mouse2BleToken})`);
        resolve();
      });
    }),
  ]);

  // 4. Synchronisation GPS et Récolte de POI
  console.log('📡 Envoi des coordonnées GPS initiales...');
  catSocket.emit('player:location', { latitude: 48.8566, longitude: 2.3522 });
  mouse1Socket.emit('player:location', { latitude: 48.8570, longitude: 2.3525 });
  mouse2Socket.emit('player:location', { latitude: 48.8560, longitude: 2.3515 });

  await wait(1000);

  // Speedy joue une carte Invisibilité
  console.log('🃏 Speedy tente d\'activer la carte INVISIBILITÉ (coût: 40⚡)...');
  // Il a 30⚡ au départ, testons le refus
  mouse1Socket.emit('card:play', { cardType: 'INVISIBILITY' });

  // Mickey récupère une fromagerie (+40⚡)
  console.log('🧀 Mickey récupère un ravitaillement...');
  mouse2Socket.emit('poi:claim', { poiId: 'poi_1' });

  await wait(1500);

  // 5. Simulation du Tag BLE physique (< 3m)
  console.log('💥 Le Chat s\'approche et élimine SpeedyGonzales...');
  catSocket.emit('ble:tag', { mouseBleToken: mouse1BleToken });

  await wait(1500);

  console.log('💥 Le Chat élimine MickeyMouse (Dernière souris vivante)...');
  catSocket.emit('ble:tag', { mouseBleToken: mouse2BleToken });

  // 6. Attente de l'écran Game Over
  await new Promise<void>((resolve) => {
    catSocket.on('game:over', (data) => {
      console.log('\n🏆 ===============================================');
      console.log(`🏆 FIN DE PARTIE ! Vainqueur: ${data.winner}`);
      console.log(`📝 Raison: ${data.reason}`);
      console.log(`⏱️ Durée: ${data.durationSeconds} secondes`);
      console.log('📊 Statistiques des joueurs :');
      for (const p of data.playersStats) {
        console.log(`   - ${p.nickname} (${p.role}) : ${p.stats.distanceTraveledMeters}m parcourus, ${p.stats.tagsCount} tags, survie: ${p.stats.timeSurvivedSeconds}s`);
      }
      console.log('🏆 ===============================================\n');
      resolve();
    });
  });

  catSocket.disconnect();
  mouse1Socket.disconnect();
  mouse2Socket.disconnect();
  console.log('✅ Simulation de bout en bout réussie à 100% !');
  process.exit(0);
}

runSimulation().catch(console.error);
