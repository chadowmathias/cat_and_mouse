# 🍏 Guide Complet : Installer sur iPhone SANS Mac (100% Gratuit)

Ce tutoriel te permet de compiler l'application Flutter et de l'installer sur ton iPhone (et ceux de tes potes) directement depuis ton PC Windows, sans jamais toucher à un Mac.

---

## 🛠️ Comment ça fonctionne en coulisses ?
1. **GitHub Actions** utilise les serveurs Mac gratuits d'Apple/GitHub dans le cloud pour compiler le projet et générer le fichier `.ipa`.
2. **Sideloadly** (logiciel gratuit sur Windows) signe le fichier `.ipa` avec ton identifiant Apple gratuit et l'installe sur ton iPhone via câble USB.

---

## 📋 Étape 1 : Générer le fichier `.ipa` sur GitHub (Automatique)

1. Crée un dépôt sur [GitHub.com](https://github.com) (privé ou public).
2. Pousse le dossier `cat_and_mouse` sur ce dépôt :
   ```bash
   git init
   git add .
   git commit -m "Cat & Mouse V1"
   git remote add origin https://github.com/TON_PSEUDO/cat_and_mouse.git
   git push -u origin main
   ```
3. Sur la page de ton dépôt GitHub :
   * Clique sur l'onglet **Actions** en haut.
   * Sélectionne le workflow **"Build iOS IPA (No Mac Required)"**.
   * Clique sur **Run workflow** ▶️.
4. Au bout de 4 à 5 minutes, le statut passe au vert ✅.
5. Clique sur la tâche terminée : en bas dans la section **Artifacts**, télécharge le fichier **`cat_and_mouse_ios_ipa`** (qui contient `cat_and_mouse.ipa`).

---

## 📲 Étape 2 : Installer sur l'iPhone depuis Windows avec Sideloadly

1. Télécharge et installe **Sideloadly** sur ton PC Windows : [sideloadly.io](https://sideloadly.io).
2. Assure-toi qu'**iTunes** ou les pilotes Apple sont installés sur ton PC Windows (Sideloadly te proposera de les installer automatiquement s'ils manquent).
3. Branche ton iPhone au PC avec le câble USB (clique sur *"Faire confiance à cet ordinateur"* sur l'écran de l'iPhone si demandé).
4. Ouvre **Sideloadly** :
   * Ton iPhone apparaît dans la case **iDevice**.
   * Glisse le fichier `cat_and_mouse.ipa` téléchargé à l'étape 1 dans la grande case IPA à gauche.
   * Renseigne ton adresse e-mail Apple ID (ton compte iCloud classique).
   * Clique sur **Start**.
5. Sideloadly va signer l'application et l'installer en 30 secondes sur ton iPhone !

---

## 🔓 Étape 3 : Autoriser l'application sur l'iPhone (Une seule fois)

Sur ton iPhone :
1. Va dans **Réglages** > **Général** > **VPN et gestion des appareils**.
2. Clique sur ton adresse Apple ID dans la liste.
3. Clique sur **"Faire confiance à [Ton adresse]"** puis valide.
4. *(Sous iOS 16, 17 ou 18)* : Active le **Mode Développeur** dans **Réglages > Confidentialité et sécurité > Mode Développeur**, puis redémarre l'iPhone.

🎉 **C'est fini ! L'icône de Cat & Mouse apparaît sur ton écran d'accueil avec tous les capteurs GPS, BLE et sonores actifs !**
