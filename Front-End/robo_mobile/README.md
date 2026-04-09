# robo_mobile

Flutter client for the WeRobo robo-advisor experience. The app now supports
mobile targets plus Flutter Web deployment to GitHub Pages.

## Local development

```bash
flutter pub get
flutter run
```

To run in a browser:

```bash
flutter run -d chrome
```

## Build for web

Root-hosted build:

```bash
bash scripts/build_web.sh
```

GitHub Pages build for this repository:

```bash
WEB_BASE_HREF=/werobo-monorepo/ bash scripts/build_web.sh
```

## GitHub Pages deployment

This repo includes a GitHub Actions workflow at
`.github/workflows/robo-mobile-pages.yml` that deploys
`Front-End/robo_mobile/build/web` to GitHub Pages on every push to `main`.

Repository settings still need one-time setup:

1. GitHub repo `Settings -> Pages`
2. `Source`: `GitHub Actions`

After that, the app will deploy to:

`https://capstone-roboadviser.github.io/werobo-monorepo/`
