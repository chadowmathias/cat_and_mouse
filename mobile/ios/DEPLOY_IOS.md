# 🍎 Guide de Déploiement iPhone (iOS) pour Cat & Mouse

Ce guide détaille comment installer l'application sur ton iPhone et ceux de tes amis.

---

## ⚙️ 1. Ce qui a déjà été configuré dans le projet

Le fichier [`mobile/ios/Runner/Info.plist`](file:///C:/Users/afsar/.gemini/antigravity/scratch/cat_and_mouse/mobile/ios/Runner/Info.plist) contient déjà toutes les clés Apple nécessaires :
* `NSLocationWhenInUseUsageDescription` (GPS Minimap)
* `NSLocationAlwaysAndWhenInUseUsageDescription` (Suivi de zone en arrière-plan)
* `NSBluetoothAlwaysUsageDescription` & `NSBluetoothPeripheralUsageDescription` (Tag BLE physique à moins de 3 mètres)
* `UIBackgroundModes` : `location`, `bluetooth-central`, `bluetooth-peripheral`, `audio`

---

## 🚀 2. Les 3 Méthodes pour installer l'app sur vos iPhones

### Méthode A : Installation USB via Xcode (100% Gratuite, Idéale si tu as un Mac)
> Aucun compte développeur payant n'est requis. Un simple compte Apple ID gratuit suffit.

1. Ouvre un terminal sur le Mac :
   ```bash
   cd mobile
   flutter build ios --no-codesign
   ```
2. Ouvre le projet dans Xcode :
   ```bash
   open ios/Runner.xcworkspace
   ```
3. Dans Xcode :
   * Clique sur **Runner** (colonne de gauche) > Onglet **Signing & Capabilities**.
   * Coche **Automatically manage signing**.
   * Sélectionne ton **Team** (ton compte Apple ID personnel gratuit).
   * Branche ton iPhone en USB (ou active le débogage réseau Wi-Fi).
   * Sélectionne ton iPhone dans la liste des appareils en haut.
   * Clique sur le bouton **Play (Run)** ▶️.
4. Sur ton iPhone :
   * Va dans *Réglages > Général > Gestion des appareils (ou VPN et gestion des appareils)*.
   * Fais confiance à ton certificat de développeur.
   * L'application se lance !

---

### Méthode B : TestFlight (La méthode Reine pour jouer à 10+ potes sans brancher de câble)
> Idéale si tu veux envoyer un lien d'invitation par SMS à toute ta bande de potes.

1. Nécessite un compte **Apple Developer Program** ($99/an).
2. Depuis le Mac :
   ```bash
   flutter build ipa
   ```
3. Téléverse l'archive sur **App Store Connect**.
4. Ajoute les adresses e-mail de tes potes dans le groupe de test **TestFlight**.
5. Ils reçoivent une notification et installent le jeu en 1 clic sur l'App Store TestFlight.

---

### Méthode C : Sideloading depuis un PC Windows (Via AltStore ou Sideloadly)
> Si tu n'as pas de Mac sous la main.

1. Installe **Sideloadly** ou **AltStore** sur ton PC Windows.
2. Compile le bundle Flutter ou génère le fichier `.ipa`.
3. Glisse le `.ipa` dans Sideloadly, renseigne ton identifiant Apple, et clique sur **Start** avec ton iPhone branché en USB.
4. L'application est installée directement sur l'iPhone.
