#!/bin/bash
# Mi Botiquín — abre el emulador Android, compila (si hace falta), instala y abre la app.
# Uso:   ./run.sh            → usa el APK ya compilado si existe
#        ./run.sh --build    → recompila antes de instalar
set -e
cd "$(dirname "$0")"

SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"
AVD="${AVD:-Pixel_8}"
PKG="mx.lasalle.mi_botiquin"
APK="build/app/outputs/flutter-apk/app-release.apk"
JDK21="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"

[ -x "$ADB" ] || { echo "No encuentro el Android SDK en $SDK (instala Android Studio)."; exit 1; }

# 1. Emulador
if ! "$ADB" devices | grep -q "emulator-.*device$"; then
  if ! "$EMULATOR" -list-avds | grep -qx "$AVD"; then
    echo "No existe el emulador $AVD. Disponibles:"; "$EMULATOR" -list-avds
    echo "Usa uno así:  AVD=NombreDelEmulador ./run.sh"; exit 1
  fi
  echo "▶ Abriendo emulador $AVD…"
  nohup "$EMULATOR" -avd "$AVD" -no-snapshot-save -no-boot-anim >/dev/null 2>&1 &
  "$ADB" wait-for-device
  until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
  echo "✓ Emulador listo"
else
  echo "✓ Emulador ya abierto"
fi

# 2. Compilar (Gradle 8.12 necesita JDK 17/21; Java 25 no sirve)
if [ "$1" = "--build" ] || [ ! -f "$APK" ]; then
  [ -d "$JDK21" ] || { echo "Falta JDK 21:  brew install openjdk@21"; exit 1; }
  echo "▶ Compilando APK release (la primera vez tarda varios minutos)…"
  flutter pub get >/dev/null
  rm -rf build/app/intermediates/flutter .dart_tool/flutter_build   # fuerza recompilar el código Dart
  (cd android && JAVA_HOME="$JDK21" ./gradlew assembleRelease -q)
  echo "✓ APK listo: $APK"
fi

# 3. Instalar con permisos y abrir
echo "▶ Instalando…"
"$ADB" install -r "$APK" >/dev/null
"$ADB" shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS 2>/dev/null || true
"$ADB" shell pm grant "$PKG" android.permission.CAMERA 2>/dev/null || true
"$ADB" shell appops set "$PKG" SCHEDULE_EXACT_ALARM allow 2>/dev/null || true
"$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
echo "✓ Mi Botiquín abierta en el emulador."
echo "  Siguiente paso: toca «Probar con datos demo» → «Cargar datos de prueba» (ver run.txt)."
