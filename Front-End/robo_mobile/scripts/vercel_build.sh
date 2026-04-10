#!/usr/bin/env bash

set -euo pipefail

FLUTTER_DIR="${HOME}/flutter"
FLUTTER_BIN="${FLUTTER_DIR}/bin/flutter"

if [ ! -x "${FLUTTER_BIN}" ]; then
  echo "Installing Flutter stable SDK for Vercel build..."
  git clone https://github.com/flutter/flutter.git \
    --depth 1 \
    --branch stable \
    "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release
