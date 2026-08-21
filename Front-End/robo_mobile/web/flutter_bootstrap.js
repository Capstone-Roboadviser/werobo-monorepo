{{flutter_js}}
{{flutter_build_config}}

const buildVersion = '{{BUILD_VERSION}}';

for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath = `${build.mainJsPath}?v=${buildVersion}`;
  }
}

_flutter.loader.load();
