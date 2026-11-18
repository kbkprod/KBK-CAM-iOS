# KBK-CAM — version iOS

Version iPhone / iPad de KBK-CAM (SwiftUI, iOS 16+), avec les mêmes fonctions que l'app Android :

- Direct **RTMP / RTMPS** (YouTube, Facebook, Twitch, serveur perso) via [HaishinKit](https://github.com/shogo4405/HaishinKit.swift) 2.2.5 (licence BSD-3).
- Tableau de score incrusté dans le direct et l'enregistrement : 14 sports, 8 styles, 6 positions, logos des équipes et des sponsors.
- Chrono croissant / décompte avec boutons (−10 / +10 s, appui long = 1 min, réglage manuel).
- Périodes et sets (mi-temps ◀ ▶, jeux ±, clore / rouvrir un set).
- Enregistrement dans Photos + temps forts (★) découpés automatiquement.
- Télécommande depuis un autre téléphone sur le même Wi-Fi (http://IP:8080).
- Arabe / français / anglais (mêmes traductions que la version Android).
- Écran d'accueil qui propose de s'abonner à la chaîne YouTube @kbkprod (facultatif, comme l'exige l'App Store).
- Écran : aperçu du direct + panneau de contrôle à droite (ou à gauche), boutons déplaçables.

## Construire l'app

Il faut un Mac (Xcode 16 ou plus récent). Le projet Xcode est généré avec [XcodeGen](https://github.com/yonaskolb/XcodeGen) :

```bash
brew install xcodegen
cd KBK-CAM-iOS
xcodegen generate
open KBKCam.xcodeproj
```

Dans Xcode : *Signing & Capabilities* → choisir ton équipe (Apple ID), brancher l'iPhone, puis ▶ Run.

### Sans Mac : GitHub Actions

Le fichier `.github/workflows/ios.yml` compile l'app sur un Mac de GitHub à chaque `push` sur `main`
et fournit un `.ipa` **non signé** dans l'onglet *Actions → Artifacts*.
Pour l'installer, il faut le signer (Sideloadly / AltStore avec un Apple ID, ou un compte Apple Developer).

### App Store / TestFlight

Voir **[APPSTORE.md](APPSTORE.md)** : conformité Apple déjà en place, envoi automatique depuis GitHub Actions,
fiche, notes pour la revue. Politique de confidentialité : **[PRIVACY.md](PRIVACY.md)**.
