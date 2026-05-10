#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLUTTER_VERSION="$(tr -d '[:space:]' < "${PROJECT_DIR}/.flutter-version")"
PROJECT_FLUTTER_BIN="${PROJECT_DIR}/.flutter-sdk/flutter/bin/flutter"
WEB_BASE_HREF="${WEB_BASE_HREF:-/}"

if [ -x "${PROJECT_FLUTTER_BIN}" ] &&
  "${PROJECT_FLUTTER_BIN}" --version | head -n 1 | grep -q "Flutter ${FLUTTER_VERSION}"; then
  FLUTTER_BIN="${PROJECT_FLUTTER_BIN}"
else
  FLUTTER_DIR="${HOME}/flutter-${FLUTTER_VERSION}"
  FLUTTER_BIN="${FLUTTER_DIR}/bin/flutter"
fi

if [ ! -x "${FLUTTER_BIN}" ]; then
  echo "Installing Flutter ${FLUTTER_VERSION} SDK..."
  git clone https://github.com/flutter/flutter.git \
    --depth 1 \
    --branch "${FLUTTER_VERSION}" \
    "${FLUTTER_DIR}"
fi

export PATH="$(dirname "${FLUTTER_BIN}"):${PATH}"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release --base-href "${WEB_BASE_HREF}"
