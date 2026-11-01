# Calculatrice — carnet de change

Application Android (Flutter) qui ressemble à une calculatrice, mais qui cache un carnet de bureau de change.

## Fonctions

- **Calculatrice qui marche vraiment.** Tapez votre **code secret puis « = »** pour ouvrir le carnet. Le carnet se referme dès que vous quittez l'app.
- **Ouverture du matin** : caisse en FCFA, USD et EUR, et taux du jour (achat / vente).
- **Clients façon messagerie** : chaque client a sa conversation avec toutes ses opérations et son solde.
- **Vente de devises** : le taux du jour est proposé et reste modifiable ; paiement partiel possible (le reste devient une dette).
- **Dettes dans les deux sens** : le client me doit / je dois au client, remboursements, dépôts.
- **Journal** : récapitulatif de chaque journée (matin, entrées, sorties, soir) et historique de toutes les opérations.
- **Hors ligne d'abord** : tout est enregistré sur le téléphone ; synchro en ligne avec Firebase quand internet est disponible.

## Installer l'app sur le téléphone

À chaque envoi de code sur `main`, GitHub construit l'APK automatiquement.

1. Sur le téléphone, ouvrez le dépôt sur github.com → **Releases** → dernière version.
2. Téléchargez le fichier `Calculatrice-v1.0.X.apk` et ouvrez-le (autorisez « sources inconnues » si Android le demande).
3. Les mises à jour s'installent par-dessus sans perdre les données (la clé de signature est toujours la même).

## Activer la synchro en ligne (Firebase)

1. Sur https://console.firebase.google.com créez un projet.
2. **Authentication** → Commencer → activez **Adresse e-mail/Mot de passe**.
3. **Firestore Database** → Créer une base de données (mode production), puis dans **Règles** collez le contenu de `firestore.rules`.
4. **Paramètres du projet** → Ajouter une app **Android** avec le nom de package `com.syllapro.calculatrice`, puis téléchargez `google-services.json`.
5. Remplissez `lib/firebase_options.dart` avec les valeurs de ce fichier (ou envoyez-les à Claude) :
   - `apiKey` ← `client[0].api_key[0].current_key`
   - `appId` ← `client[0].client_info.mobilesdk_app_id`
   - `messagingSenderId` ← `project_info.project_number`
   - `projectId` ← `project_info.project_id`
   - `storageBucket` ← `project_info.storage_bucket`
6. Dans l'app : **Réglages → Sauvegarde en ligne → Créer un compte**, puis utilisez le même compte sur chaque téléphone.

## Développement

```bash
bash tool/prepare_android.sh   # génère android/
flutter pub get
dart run flutter_launcher_icons
flutter run
```

Structure : `lib/core` (montants, calculatrice, code secret), `lib/data` (base locale, calculs de caisse et dettes), `lib/sync` (Firebase), `lib/ui` (écrans).
