export type PlayerRole = 'NONE' | 'CAT' | 'MOUSE';

export type GameStatus = 'LOBBY' | 'HEAD_START' | 'HUNTING' | 'PAUSED' | 'FINISHED';

export type CardType = 'INVISIBILITY' | 'DECOY' | 'SONAR';

export interface GeoLocation {
  latitude: number;
  longitude: number;
  accuracy?: number;
  timestamp: number;
  isMocked?: boolean;
}

export interface PlayerStats {
  distanceTraveledMeters: number;
  cardsUsedCount: number;
  totalAdrenalineEarned: number;
  timeSurvivedSeconds: number;
  tagsCount: number; // Pour les chats
}

export interface Player {
  id: string;
  nickname: string;
  role: PlayerRole;
  isHost: boolean;
  isAlive: boolean;
  location?: GeoLocation;
  lastRadarPingLocation?: GeoLocation;
  adrenalinePoints: number;
  bleSessionToken: string;
  outOfZoneSince?: number;

  // Statistiques de fin de partie
  stats: PlayerStats;

  // Anti-Triche
  overspeedWarningSince?: number;
  lastCalculatedSpeedKmH?: number;

  // Effets actifs de cartes
  activeEffects: {
    isInvisibleUntil?: number;
    activeDecoyLocation?: GeoLocation;
    isSonarActiveUntil?: number;
  };
}

export interface SupplyPOI {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  isAvailable: boolean;
  cooldownUntil?: number;
}

export interface GameZone {
  center: {
    latitude: number;
    longitude: number;
  };
  currentRadius: number;
  initialRadius: number;
  minRadius: number;
  currentWaveIndex: number;
  targetRadius?: number;
  isWarningShrink: boolean;
  shrinkWarningEndsAt?: number;
  nextWaveStartsAt?: number;
}

export interface GameOverData {
  winner: 'CATS' | 'MICE';
  reason: string;
  durationSeconds: number;
  playersStats: Array<{
    id: string;
    nickname: string;
    role: PlayerRole;
    isAlive: boolean;
    stats: PlayerStats;
  }>;
}

export interface GameRoom {
  code: string;
  hostId: string;
  status: GameStatus;
  zone: GameZone;
  players: Map<string, Player>;
  pois: SupplyPOI[];

  headStartDurationMs: number;
  radarIntervalMs: number;
  gameDurationMs: number;
  startedAt?: number;
  headStartEndsAt?: number;
  nextRadarPingAt?: number;
  gameOverData?: GameOverData;
}
