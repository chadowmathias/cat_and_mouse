import { GameRoom, Player, PlayerRole, GameStatus, GeoLocation, SupplyPOI, CardType, GameOverData } from '../types/game.js';
import { calculateDistance, isInsideZone, generateRandomPointInCircle, generateOffsetPoint } from '../utils/geo.js';
import crypto from 'crypto';

export const CARD_COSTS: Record<CardType, number> = {
  INVISIBILITY: 40,
  DECOY: 30,
  SONAR: 45,
};

export const MAX_ALLOWED_SPEED_KMH = 25.0;
export const OVERSPEED_GRACE_PERIOD_MS = 10000;

export class GameManager {
  private rooms: Map<string, GameRoom> = new Map();

  public generateRoomCode(): string {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let code = '';
    do {
      code = Array.from({ length: 6 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
    } while (this.rooms.has(code));
    return code;
  }

  public getAllRooms(): Map<string, GameRoom> {
    return this.rooms;
  }

  public createRoom(
    hostId: string,
    nickname: string,
    centerLat: number,
    centerLng: number,
    initialRadiusMeters: number = 800
  ): GameRoom {
    const code = this.generateRoomCode();
    const bleToken = crypto.randomBytes(4).toString('hex').toUpperCase();

    const hostPlayer: Player = {
      id: hostId,
      nickname,
      role: 'NONE',
      isHost: true,
      isAlive: true,
      adrenalinePoints: 30,
      bleSessionToken: bleToken,
      activeEffects: {},
      stats: {
        distanceTraveledMeters: 0,
        cardsUsedCount: 0,
        totalAdrenalineEarned: 30,
        timeSurvivedSeconds: 0,
        tagsCount: 0,
      },
    };

    const pois: SupplyPOI[] = [];
    const poiNames = ['Fromagerie du Parc', 'Station Ravitaillement Alpha', 'Point Relais Oméga'];
    for (let i = 0; i < 3; i++) {
      const pt = generateRandomPointInCircle({ latitude: centerLat, longitude: centerLng }, initialRadiusMeters * 0.75);
      pois.push({
        id: `poi_${i + 1}`,
        name: poiNames[i],
        latitude: pt.latitude,
        longitude: pt.longitude,
        isAvailable: true,
      });
    }

    const room: GameRoom = {
      code,
      hostId,
      status: 'LOBBY',
      zone: {
        center: { latitude: centerLat, longitude: centerLng },
        currentRadius: initialRadiusMeters,
        initialRadius: initialRadiusMeters,
        minRadius: Math.max(150, Math.floor(initialRadiusMeters * 0.25)),
        currentWaveIndex: 1,
        isWarningShrink: false,
      },
      players: new Map([[hostId, hostPlayer]]),
      pois,
      headStartDurationMs: 5 * 60 * 1000,
      radarIntervalMs: 2.5 * 60 * 1000,
      gameDurationMs: 25 * 60 * 1000, // 25 minutes de partie max
    };

    this.rooms.set(code, room);
    return room;
  }

  public getRoom(code: string): GameRoom | undefined {
    return this.rooms.get(code);
  }

  public joinRoom(code: string, playerId: string, nickname: string): Player | null {
    const room = this.rooms.get(code);
    if (!room || room.status !== 'LOBBY') return null;

    const bleToken = crypto.randomBytes(4).toString('hex').toUpperCase();

    const player: Player = {
      id: playerId,
      nickname,
      role: 'NONE',
      isHost: false,
      isAlive: true,
      adrenalinePoints: 30,
      bleSessionToken: bleToken,
      activeEffects: {},
      stats: {
        distanceTraveledMeters: 0,
        cardsUsedCount: 0,
        totalAdrenalineEarned: 30,
        timeSurvivedSeconds: 0,
        tagsCount: 0,
      },
    };

    room.players.set(playerId, player);
    return player;
  }

  public removePlayer(playerId: string): { roomCode: string; room: GameRoom } | null {
    for (const [code, room] of this.rooms.entries()) {
      if (room.players.has(playerId)) {
        room.players.delete(playerId);
        if (room.players.size === 0) {
          this.rooms.delete(code);
          return null;
        }
        if (room.hostId === playerId) {
          const nextHost = room.players.keys().next().value;
          if (nextHost) {
            room.hostId = nextHost;
            const p = room.players.get(nextHost);
            if (p) p.isHost = true;
          }
        }
        return { roomCode: code, room };
      }
    }
    return null;
  }

  public startGame(code: string, requestedCatCount?: number): { success: boolean; error?: string } {
    const room = this.rooms.get(code);
    if (!room) return { success: false, error: 'Salon introuvable.' };
    if (room.players.size < 2) return { success: false, error: 'Il faut au moins 2 joueurs.' };

    const playersArray = Array.from(room.players.values());
    const totalPlayers = playersArray.length;
    const catCount = requestedCatCount ?? (totalPlayers >= 5 ? 2 : 1);

    const shuffled = [...playersArray].sort(() => Math.random() - 0.5);

    for (let i = 0; i < shuffled.length; i++) {
      const player = shuffled[i];
      player.role = i < catCount ? 'CAT' : 'MOUSE';
      player.isAlive = true;
      player.adrenalinePoints = 30;
      player.activeEffects = {};
      player.stats = {
        distanceTraveledMeters: 0,
        cardsUsedCount: 0,
        totalAdrenalineEarned: 30,
        timeSurvivedSeconds: 0,
        tagsCount: 0,
      };
    }

    const now = Date.now();
    room.status = 'HEAD_START';
    room.startedAt = now;
    room.headStartEndsAt = now + room.headStartDurationMs;
    room.nextRadarPingAt = now + room.headStartDurationMs;

    room.zone.currentWaveIndex = 1;
    room.zone.nextWaveStartsAt = now + 7 * 60 * 1000;

    return { success: true };
  }

  public playCard(
    code: string,
    playerId: string,
    cardType: CardType
  ): { success: boolean; error?: string; message?: string; targetDecoyLocation?: GeoLocation } {
    const room = this.rooms.get(code);
    if (!room) return { success: false, error: 'Partie introuvable.' };

    const player = room.players.get(playerId);
    if (!player || !player.isAlive) return { success: false, error: 'Joueur non actif.' };

    const cost = CARD_COSTS[cardType];
    if (player.adrenalinePoints < cost) {
      return { success: false, error: `Adrénaline insuffisante (${player.adrenalinePoints}/${cost} requis).` };
    }

    const now = Date.now();
    player.stats.cardsUsedCount += 1;

    switch (cardType) {
      case 'INVISIBILITY':
        if (player.role !== 'MOUSE') return { success: false, error: 'Réservé aux Souris.' };
        player.adrenalinePoints -= cost;
        player.activeEffects.isInvisibleUntil = now + 180 * 1000;
        return { success: true, message: '👻 Invisibilité active ! Vous êtes masqué du prochain scan radar.' };

      case 'DECOY':
        if (player.role !== 'MOUSE') return { success: false, error: 'Réservé aux Souris.' };
        if (!player.location) return { success: false, error: 'Position GPS requise pour déployer le leurre.' };
        player.adrenalinePoints -= cost;
        const fakeCoord = generateOffsetPoint(
          { latitude: player.location.latitude, longitude: player.location.longitude },
          150
        );
        player.activeEffects.activeDecoyLocation = {
          latitude: fakeCoord.latitude,
          longitude: fakeCoord.longitude,
          timestamp: now,
        };
        return {
          success: true,
          message: '🎭 Leurre déployé à 150m ! Le radar affichera un faux écho.',
          targetDecoyLocation: player.activeEffects.activeDecoyLocation,
        };

      case 'SONAR':
        if (player.role !== 'CAT') return { success: false, error: 'Réservé aux Chats.' };
        player.adrenalinePoints -= cost;
        player.activeEffects.isSonarActiveUntil = now + 45 * 1000;
        return { success: true, message: '📡 Sonar activé pour 45 secondes !' };

      default:
        return { success: false, error: 'Carte inconnue.' };
    }
  }

  public getSonarDistanceForCat(code: string, catId: string): number | null {
    const room = this.rooms.get(code);
    if (!room) return null;

    const cat = room.players.get(catId);
    if (!cat || cat.role !== 'CAT' || !cat.location) return null;

    const now = Date.now();
    if (!cat.activeEffects.isSonarActiveUntil || cat.activeEffects.isSonarActiveUntil < now) {
      return null;
    }

    let minDistance = Infinity;
    for (const p of room.players.values()) {
      if (p.role === 'MOUSE' && p.isAlive && p.location) {
        const d = calculateDistance(
          { latitude: cat.location.latitude, longitude: cat.location.longitude },
          { latitude: p.location.latitude, longitude: p.location.longitude }
        );
        if (d < minDistance) minDistance = d;
      }
    }

    return minDistance === Infinity ? null : Math.round(minDistance);
  }

  public claimPoi(code: string, playerId: string, poiId: string): { success: boolean; error?: string; reward?: number } {
    const room = this.rooms.get(code);
    if (!room) return { success: false, error: 'Partie introuvable.' };

    const player = room.players.get(playerId);
    if (!player || !player.isAlive || !player.location) return { success: false, error: 'Position requise.' };

    const poi = room.pois.find((p) => p.id === poiId);
    if (!poi || !poi.isAvailable) return { success: false, error: 'Ravitaillement indisponible.' };

    const dist = calculateDistance(
      { latitude: player.location.latitude, longitude: player.location.longitude },
      { latitude: poi.latitude, longitude: poi.longitude }
    );

    if (dist > 25) {
      return { success: false, error: `Trop loin du point (${Math.round(dist)}m).` };
    }

    player.adrenalinePoints += 40;
    player.stats.totalAdrenalineEarned += 40;
    poi.isAvailable = false;
    poi.cooldownUntil = Date.now() + 180 * 1000;

    return { success: true, reward: 40 };
  }

  public updatePlayerLocation(
    code: string,
    playerId: string,
    loc: GeoLocation
  ): {
    isInside: boolean;
    outOfZoneSince?: number;
    player?: Player;
    proximityBonus?: boolean;
    cheatAlert?: { type: 'MOCK_GPS' | 'OVERSPEED_WARNING' | 'OVERSPEED_ELIMINATED'; speedKmh?: number };
  } {
    const room = this.rooms.get(code);
    if (!room) return { isInside: true };

    const player = room.players.get(playerId);
    if (!player || !player.isAlive) return { isInside: true };

    const now = Date.now();

    if (loc.isMocked) {
      player.isAlive = false;
      return { isInside: true, player, cheatAlert: { type: 'MOCK_GPS' } };
    }

    let cheatAlert: { type: 'MOCK_GPS' | 'OVERSPEED_WARNING' | 'OVERSPEED_ELIMINATED'; speedKmh?: number } | undefined;

    if (player.location && loc.timestamp > player.location.timestamp) {
      const dtSeconds = (loc.timestamp - player.location.timestamp) / 1000;
      if (dtSeconds >= 1.5) {
        const dist = calculateDistance(
          { latitude: player.location.latitude, longitude: player.location.longitude },
          { latitude: loc.latitude, longitude: loc.longitude }
        );

        // Cumul de la distance parcourue à pied
        player.stats.distanceTraveledMeters += Math.round(dist);

        const speedKmh = (dist / dtSeconds) * 3.6;
        player.lastCalculatedSpeedKmH = Math.round(speedKmh * 10) / 10;

        if (speedKmh > MAX_ALLOWED_SPEED_KMH) {
          if (!player.overspeedWarningSince) {
            player.overspeedWarningSince = now;
            cheatAlert = { type: 'OVERSPEED_WARNING', speedKmh: player.lastCalculatedSpeedKmH };
          } else if (now - player.overspeedWarningSince > OVERSPEED_GRACE_PERIOD_MS) {
            player.isAlive = false;
            cheatAlert = { type: 'OVERSPEED_ELIMINATED', speedKmh: player.lastCalculatedSpeedKmH };
          }
        } else {
          player.overspeedWarningSince = undefined;
        }
      }
    }

    player.location = loc;

    const inside = isInsideZone(
      { latitude: loc.latitude, longitude: loc.longitude },
      room.zone.center,
      room.zone.currentRadius
    );

    if (!inside) {
      if (!player.outOfZoneSince) player.outOfZoneSince = now;
    } else {
      player.outOfZoneSince = undefined;
    }

    let proximityBonus = false;
    if (player.role === 'MOUSE' && player.isAlive && inside) {
      for (const other of room.players.values()) {
        if (other.role === 'CAT' && other.isAlive && other.location) {
          const d = calculateDistance(
            { latitude: loc.latitude, longitude: loc.longitude },
            { latitude: other.location.latitude, longitude: other.location.longitude }
          );
          if (d >= 20 && d <= 55) {
            player.adrenalinePoints += 2;
            player.stats.totalAdrenalineEarned += 2;
            proximityBonus = true;
            break;
          }
        }
      }
    }

    return { isInside: inside, outOfZoneSince: player.outOfZoneSince, player, proximityBonus, cheatAlert };
  }

  public processBleTag(
    code: string,
    catId: string,
    mouseBleToken: string
  ): { success: boolean; eliminatedMouse?: Player; error?: string } {
    const room = this.rooms.get(code);
    if (!room) return { success: false, error: 'Salon introuvable.' };

    const cat = room.players.get(catId);
    if (!cat || cat.role !== 'CAT') return { success: false, error: 'Seul un Chat peut éliminer.' };

    let taggedMouse: Player | undefined;
    for (const p of room.players.values()) {
      if (p.bleSessionToken === mouseBleToken && p.role === 'MOUSE') {
        taggedMouse = p;
        break;
      }
    }

    if (!taggedMouse || !taggedMouse.isAlive) {
      return { success: false, error: 'Souris introuvable ou déjà éliminée.' };
    }

    if (cat.location && taggedMouse.location) {
      const dist = calculateDistance(
        { latitude: cat.location.latitude, longitude: cat.location.longitude },
        { latitude: taggedMouse.location.latitude, longitude: taggedMouse.location.longitude }
      );
      if (dist > 45) {
        return { success: false, error: 'Incohérence GPS (>45m) pour un contact physique.' };
      }
    }

    taggedMouse.isAlive = false;
    cat.stats.tagsCount += 1;

    // Calcul du temps de survie
    if (room.startedAt) {
      taggedMouse.stats.timeSurvivedSeconds = Math.round((Date.now() - room.startedAt) / 1000);
    }

    return { success: true, eliminatedMouse: taggedMouse };
  }

  /**
   * Vérifie les conditions de victoire de fin de partie
   */
  public evaluateGameEnd(code: string): GameOverData | null {
    const room = this.rooms.get(code);
    if (!room || room.status === 'LOBBY' || room.status === 'FINISHED') return null;

    const now = Date.now();
    const mice = Array.from(room.players.values()).filter((p) => p.role === 'MOUSE');
    const aliveMice = mice.filter((m) => m.isAlive);

    let winner: 'CATS' | 'MICE' | null = null;
    let reason = '';

    // Condition A : Toutes les souris sont éliminées -> Victoire des Chats
    if (mice.length > 0 && aliveMice.length === 0) {
      winner = 'CATS';
      reason = 'Tous les rongeurs ont été capturés ! Victoire éclatante des Chats.';
    }

    // Condition B : Temps global de la partie écoulé -> Victoire des Souris survivantes
    const gameDurationMs = room.gameDurationMs || 25 * 60 * 1000;
    if (!winner && room.startedAt && now - room.startedAt >= gameDurationMs) {
      winner = 'MICE';
      reason = 'Temps écoulé ! Les Souris survivantes ont réussi à échapper aux prédateurs.';
    }

    if (!winner) return null;

    // Calcul final des stats de tous les joueurs
    const durationSeconds = room.startedAt ? Math.round((now - room.startedAt) / 1000) : 0;
    const playersStats = Array.from(room.players.values()).map((p) => {
      if (p.isAlive) {
        p.stats.timeSurvivedSeconds = durationSeconds;
      }
      return {
        id: p.id,
        nickname: p.nickname,
        role: p.role,
        isAlive: p.isAlive,
        stats: p.stats,
      };
    });

    const gameOverData: GameOverData = {
      winner,
      reason,
      durationSeconds,
      playersStats,
    };

    room.status = 'FINISHED';
    room.gameOverData = gameOverData;
    return gameOverData;
  }

  public generateRadarPingForCats(code: string): Array<{ id: string; nickname: string; latitude: number; longitude: number; isDecoy?: boolean }> {
    const room = this.rooms.get(code);
    if (!room) return [];

    const now = Date.now();
    const blips: Array<{ id: string; nickname: string; latitude: number; longitude: number; isDecoy?: boolean }> = [];

    for (const player of room.players.values()) {
      if (player.role === 'MOUSE' && player.isAlive) {
        if (player.activeEffects.isInvisibleUntil && player.activeEffects.isInvisibleUntil > now) {
          continue;
        }

        if (player.activeEffects.activeDecoyLocation) {
          blips.push({
            id: `decoy_${player.id}`,
            nickname: player.nickname,
            latitude: player.activeEffects.activeDecoyLocation.latitude,
            longitude: player.activeEffects.activeDecoyLocation.longitude,
            isDecoy: true,
          });
          player.activeEffects.activeDecoyLocation = undefined;
          continue;
        }

        if (player.location) {
          player.lastRadarPingLocation = player.location;
          blips.push({
            id: player.id,
            nickname: player.nickname,
            latitude: player.location.latitude,
            longitude: player.location.longitude,
          });
        }
      }
    }

    return blips;
  }

  public serializeRoom(room: GameRoom, forPlayerId: string): any {
    const requestingPlayer = room.players.get(forPlayerId);
    const playersList: any[] = [];

    for (const p of room.players.values()) {
      const isSelf = p.id === forPlayerId;
      const isCat = requestingPlayer?.role === 'CAT';

      playersList.push({
        id: p.id,
        nickname: p.nickname,
        role: p.role,
        isHost: p.isHost,
        isAlive: p.isAlive,
        adrenalinePoints: isSelf ? p.adrenalinePoints : undefined,
        bleSessionToken: isSelf ? p.bleSessionToken : undefined,
        location: isSelf || (isCat && p.role === 'CAT') ? p.location : undefined,
      });
    }

    return {
      code: room.code,
      status: room.status,
      hostId: room.hostId,
      zone: room.zone,
      pois: room.pois,
      players: playersList,
      headStartEndsAt: room.headStartEndsAt,
      nextRadarPingAt: room.nextRadarPingAt,
      gameOverData: room.gameOverData,
    };
  }
}
