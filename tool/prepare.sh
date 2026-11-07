#!/usr/bin/env bash
# Erzeugt die Plattform-Ordner (android/, windows/) im Build-Server.
set -e
flutter create --project-name handyapp --org de.alex468187 --platforms=android,windows .
rm -f test/widget_test.dart

# Angezeigter App-Name
sed -i 's/android:label="handyapp"/android:label="Kairo"/' android/app/src/main/AndroidManifest.xml
if [ -f windows/runner/main.cpp ]; then
  sed -i 's/L"handyapp"/L"Kairo"/' windows/runner/main.cpp
fi

# Android: Berechtigungen (Mikrofon, Benachrichtigungen) und Gradle-Einstellungen
if [ "$RUNNER_OS" != "Windows" ]; then
  python3 tool/patch_android.py
fi
