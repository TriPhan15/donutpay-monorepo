#!/usr/bin/env bash
# Rebuild + reinstall app on connected phone.
# IP = PC LAN IP (same WiFi as phone). Backend and AI go through the compose proxy on port 80 (8080/8000 are internal).
# Usage: PC_IP=x.x.x.x ./deploy.sh
set -e

if [ -z "${PC_IP:-}" ]; then
  echo "PC_IP is required (the PC's LAN IP). Usage: PC_IP=x.x.x.x ./deploy.sh" >&2
  exit 1
fi
# Must match applicationId in android/app/build.gradle.kts.
PKG="dev.ledgermind.dev"

cd "$(dirname "$0")"

echo ">> Build APK (API/ML -> $PC_IP)"
flutter build apk --release \
  --dart-define=API_BASE=http://${PC_IP} \
  --dart-define=ML_BASE=http://${PC_IP}/ai

echo ">> Install on phone"
adb install -r build/app/outputs/flutter-apk/app-release.apk \
  || { echo "Reinstall failed -> uninstall + retry"; adb uninstall "$PKG"; \
       adb install build/app/outputs/flutter-apk/app-release.apk; }

echo ">> Done"
