#!/usr/bin/env bash
# Prépare le dossier android/ (généré par Flutter) avec les réglages de l'app.
# Utilisé par GitHub Actions, et utilisable sur votre ordinateur :  bash tool/prepare_android.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ]; then
  flutter create --org com.syllapro --project-name calculatrice --platforms=android .
fi

# Le test d'exemple généré par Flutter ne correspond pas à cette app.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm test/widget_test.dart
fi

MANIFEST=android/app/src/main/AndroidManifest.xml
# Nom affiché sous l'icône.
sed -i.bak 's/android:label="[^"]*"/android:label="Calculatrice"/' "$MANIFEST"
# Accès internet (synchro en ligne) aussi en version finale.
if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i.bak 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi
rm -f "$MANIFEST.bak"

# Firebase demande Android 6 (API 23) minimum.
GRADLE=android/app/build.gradle.kts
if [ -f "$GRADLE" ]; then
  sed -i.bak 's/minSdk = flutter.minSdkVersion/minSdk = maxOf(flutter.minSdkVersion, 23)/' "$GRADLE"
  rm -f "$GRADLE.bak"
fi

echo "android/ prêt."
