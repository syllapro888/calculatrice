// Configuration Firebase.
//
// Ce fichier est un modèle : tant que les valeurs valent "A_CONFIGURER",
// l'app fonctionne uniquement en local. Pour activer la synchro en ligne,
// remplacez ce fichier par celui généré par `flutterfire configure`
// ou remplissez les valeurs depuis google-services.json (voir README).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'A_CONFIGURER',
    appId: 'A_CONFIGURER',
    messagingSenderId: 'A_CONFIGURER',
    projectId: 'A_CONFIGURER',
    storageBucket: '',
  );
}
