/**
 * Utilitaires géographiques pour le calcul de distance, geofencing et génération de points
 */

export interface LatLng {
  latitude: number;
  longitude: number;
}

const EARTH_RADIUS_METERS = 6371000;

/**
 * Calcule la distance en mètres entre deux coordonnées GPS via la formule de Haversine
 */
export function calculateDistance(coord1: LatLng, coord2: LatLng): number {
  const dLat = toRadians(coord2.latitude - coord1.latitude);
  const dLon = toRadians(coord2.longitude - coord1.longitude);

  const lat1 = toRadians(coord1.latitude);
  const lat2 = toRadians(coord2.latitude);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) * Math.sin(dLon / 2) * Math.cos(lat1) * Math.cos(lat2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return EARTH_RADIUS_METERS * c;
}

/**
 * Vérifie si une coordonnée se trouve à l'intérieur d'un rayon donné par rapport à un centre
 */
export function isInsideZone(point: LatLng, center: LatLng, radiusMeters: number): boolean {
  const distance = calculateDistance(point, center);
  return distance <= radiusMeters;
}

/**
 * Génère un point aléatoire uniformément distribué à l'intérieur d'un cercle
 */
export function generateRandomPointInCircle(center: LatLng, maxRadiusMeters: number): LatLng {
  // Distribution uniforme dans le disque
  const r = maxRadiusMeters * Math.sqrt(Math.random() * 0.8 + 0.1); // entre 10% et 90% du rayon
  const theta = Math.random() * 2 * Math.PI;

  const dx = r * Math.cos(theta);
  const dy = r * Math.sin(theta);

  const deltaLat = (dy / EARTH_RADIUS_METERS) * (180 / Math.PI);
  const deltaLng = (dx / (EARTH_RADIUS_METERS * Math.cos(toRadians(center.latitude)))) * (180 / Math.PI);

  return {
    latitude: center.latitude + deltaLat,
    longitude: center.longitude + deltaLng,
  };
}

/**
 * Génère un point décalé à une distance fixe (ex: pour la carte Leurre)
 */
export function generateOffsetPoint(origin: LatLng, distanceMeters: number): LatLng {
  const angle = Math.random() * 2 * Math.PI;
  const dx = distanceMeters * Math.cos(angle);
  const dy = distanceMeters * Math.sin(angle);

  const deltaLat = (dy / EARTH_RADIUS_METERS) * (180 / Math.PI);
  const deltaLng = (dx / (EARTH_RADIUS_METERS * Math.cos(toRadians(origin.latitude)))) * (180 / Math.PI);

  return {
    latitude: origin.latitude + deltaLat,
    longitude: origin.longitude + deltaLng,
  };
}

function toRadians(degrees: number): number {
  return degrees * (Math.PI / 180);
}
