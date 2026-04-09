#!/usr/bin/env bash

set -euo pipefail

BASE_HREF="${WEB_BASE_HREF:-/}"

if [[ "${BASE_HREF}" != /* ]]; then
  BASE_HREF="/${BASE_HREF}"
fi

if [[ "${BASE_HREF}" != */ ]]; then
  BASE_HREF="${BASE_HREF}/"
fi

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release --base-href "${BASE_HREF}"
touch build/web/.nojekyll
