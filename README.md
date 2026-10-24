# 🐾 Cat & Mouse - Real Life Edition (Grandeur Nature)

Jeu mobile géolocalisé temps réel type "Chat et Souris" dans le monde réel.

---

## 📁 Architecture du Projet

```
cat_and_mouse/
├── backend/                  # Serveur Node.js / TypeScript + Socket.io
│   ├── src/
│   │   ├── managers/         # Gestionnaire de rooms, rôles & état de jeu
│   │   ├── types/            # Types TypeScript partagés
│   │   ├── utils/            # Moteur de calculs géographiques (Haversine)
│   │   └── server.ts         # Passerelle WebSocket en temps réel
│   ├── package.json
│   └── tsconfig.json
│
└── mobile/                   # Application Mobile Flutter (iOS & Android)
    ├── lib/
    │   ├── models/           # Modèles de données (Joueur, Session)
    │   ├── services/         # SocketService, LocationService (GPS), BleService (Tag)
    │   ├── screens/          # HomeScreen (Slider Option A), LobbyScreen, GameScreen
    │   └── main.dart         # Point d'entrée MultiProvider
    └── pubspec.yaml
```

---

## 🚀 Démarrage Rapide

### 1. Lancer le Serveur Backend

Dans un terminal :
```bash
cd backend
npm run dev
```
Le serveur démarrera sur `http://localhost:3000` et affichera les logs de connexion en direct.

---

### 2. Lancer l'Application Mobile (Flutter)

Dans un terminal :
```bash
cd mobile
flutter pub get
flutter run
```

> **Note Réseau pour les Tests** :
> - Sur **Émulateur Android** : L'adresse du serveur est configurée par défaut sur `http://10.0.2.2:3000`.
> - Sur **Téléphone Physique** : Renseigne l'adresse IP locale de ton PC (ex: `http://192.168.1.XX:3000`) sur l'écran d'accueil de l'application.

---

## 📡 Permissions Requises

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Le jeu nécessite votre position pour afficher la minimap et vérifier la zone de jeu.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Le Bluetooth est requis pour détecter physiquement l'approche d'un Chat à moins de 3 mètres.</string>
```
