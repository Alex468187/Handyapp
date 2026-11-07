#!/usr/bin/env bash
# Erzeugt die Plattform-Ordner (android/, windows/) im Build-Server.
set -e
flutter create --project-name handyapp --org de.alex468187 --platforms=android,windows .
rm -f test/widget_test.dart

# Angezeigter App-Name
sed -i 's/android:label="handyapp"/android:label="Summer"/' android/app/src/main/AndroidManifest.xml
if [ -f windows/runner/main.cpp ]; then
  sed -i 's/L"handyapp"/L"Summer"/' windows/runner/main.cpp
  # flutter_local_notifications_windows nutzt <experimental/coroutine>,
  # das neue Visual-Studio-Versionen sonst als Fehler ablehnen.
  sed -i '/^project(/a add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)' windows/CMakeLists.txt
fi

# Android: Berechtigungen (Mikrofon, Benachrichtigungen) und Gradle-Einstellungen
if [ "$RUNNER_OS" != "Windows" ]; then
  python3 tool/patch_android.py
fi
