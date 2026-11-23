#!/usr/bin/env bash
# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Setting up Flutter SDK for Render ==="
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi

export PATH="$HOME/flutter/bin:$PATH"

echo "=== Checking Flutter Version ==="
flutter --version

echo "=== Enabling Web ==="
flutter config --enable-web

echo "=== Installing Dependencies ==="
flutter pub get

echo "=== Building Flutter Web (Release) ==="
flutter build web --release

echo "=== Build Successful! Output ready in build/web ==="
