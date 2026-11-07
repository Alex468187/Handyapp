# Handyapp

Persönliche Manager-App (To-dos/Kalender, Notizen, Passwörter, Nachrichten, Dateien teilen) für Android + Windows. Flutter.
Der Nutzer programmiert nicht selbst – er testet nur die fertigen Builds.

## Obsidian
- Projektnotiz: `C:\Users\email\OneDrive\Dokumente\Obsidian Vault\Projekte\Handyapp.md`
- Wichtige Entscheidungen, neuer Stand und offene Aufgaben dort eintragen.
- Regeln des Vaults stehen in `C:\Users\email\OneDrive\Dokumente\Obsidian Vault\CLAUDE.md`.

## Build
- Kein Flutter lokal (zu wenig Speicherplatz). Gebaut wird nur per GitHub Actions (`.github/workflows/build.yml`) bei jedem Push auf `main`.
- `android/` und `windows/` werden nicht eingecheckt, sondern im Build von `tool/prepare.sh` per `flutter create` erzeugt. Anpassungen an diesen Dateien also dort per Skript machen.
- Ergebnis: GitHub-Release `build-<Nummer>` mit `Kairo.apk` und `Kairo-Windows.zip`.
- Build verfolgen: `gh run watch` bzw. `gh run view --log-failed`.
- Signatur-Schlüssel: `keys/debug.keystore` (nicht im Git, liegt als Secret `DEBUG_KEYSTORE` bei GitHub). Nicht verlieren, sonst lassen sich Updates nicht mehr drüber installieren.
