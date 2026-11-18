# Publier KBK-CAM sur l'App Store

## Ce qui est déjà prêt dans le projet

| Exigence Apple | Où |
|---|---|
| Pas d'action obligatoire pour utiliser l'app (règle 3.2.2) : l'abonnement YouTube est seulement proposé, « Continuer » marche toujours | `GateView.swift` |
| Manifeste de confidentialité (obligatoire depuis 2024) : aucune donnée collectée, pas de tracking, raisons d'API déclarées | `KBKCam/Resources/PrivacyInfo.xcprivacy` |
| Déclaration de chiffrement (`ITSAppUsesNonExemptEncryption = false`) : seul le chiffrement standard (HTTPS/RTMPS) est utilisé | `Info.plist` |
| Messages d'autorisation clairs (caméra, micro, Photos, réseau local) en arabe, français et anglais | `Resources/*.lproj/InfoPlist.strings` |
| Icône 1024 × 1024 sans transparence | `Assets.xcassets/AppIcon.appiconset` |
| Écran de lancement, pas de mode arrière-plan inutile, pas de compte, pas de pub | `Info.plist` |
| Compilation avec le dernier SDK iOS (exigé pour les envois) | `.github/workflows/ios.yml` (`macos-26`) |
| Envoi automatique vers App Store Connect / TestFlight | job `appstore` du workflow + `ExportOptions.plist` |
| Politique de confidentialité (URL obligatoire) | `PRIVACY.md` (à publier en ligne) |

L'app est pour **iPhone** (elle tourne aussi sur iPad en mode compatibilité). Identifiant : `com.kbk.cam`.

## Étapes

1. **Compte Apple Developer** (99 $/an) : https://developer.apple.com/programs/
2. **App Store Connect** → *Apps* → **+** → Nouvelle app : plateforme iOS, nom « KBK-CAM », langue principale,
   identifiant de bundle `com.kbk.cam`, SKU libre (ex. `kbkcam`).
3. **Politique de confidentialité** : publie `PRIVACY.md` en ligne (GitHub Pages, Google Sites…) et colle l'URL dans
   *App Privacy*.
4. **Confidentialité de l'app** (*App Privacy*) : répondre **« Data Not Collected »** (aucune donnée collectée).
5. **Clé API** : App Store Connect → *Users and Access* → *Integrations* → *App Store Connect API* → nouvelle clé,
   rôle *App Manager*. Télécharge le `.p8` (une seule fois possible).
6. **Secrets GitHub** du dépôt : `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`
   (le contenu du `.p8` encodé en base64 : `base64 -i AuthKey_XXXX.p8`).
7. **Envoyer un build** : GitHub → *Actions* → *iOS build* → *Run workflow* → cocher *upload_to_app_store*.
   Le build apparaît dans TestFlight après le traitement par Apple (10 à 30 min).
   *(Avec un Mac : Xcode → Product → Archive → Distribute App → App Store Connect.)*
8. **Fiche App Store** : description, mots-clés, captures d'écran iPhone 6,9" (1320 × 2868 ou 2868 × 1320 en paysage),
   catégorie *Sports*, classification d'âge (4+).
9. **Notes pour la revue** (*App Review Information*) — à coller :

   > KBK-CAM films sports matches with a live scoreboard overlay and can stream to any RTMP server the user owns
   > (YouTube, Facebook, Twitch...). No account is needed. To test without a stream key: tap the team cards to add
   > points, use the clock buttons, then tap "● REC" to record — the video (with the scoreboard) is saved to Photos.
   > Live streaming requires the user's own RTMP URL and stream key. The YouTube subscribe button on the welcome
   > screen is optional; "Continue to the app" always works.

10. **Soumettre pour la revue.**

## Points d'attention

- La **première compilation** n'a pas encore été faite (le code a été écrit sous Windows) : lance le job `build`
  d'abord et corrige les éventuelles erreurs avant l'envoi.
- Teste sur un vrai iPhone via **TestFlight** avant de soumettre (caméra, direct, enregistrement, temps forts).
- Les noms YouTube / Facebook / Twitch sont seulement cités comme compatibles (pas de logos de ces marques dans l'app).
