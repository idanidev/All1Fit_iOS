fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios bump_build

```sh
[bundle exec] fastlane ios bump_build
```

Incrementa el build number al siguiente de TestFlight

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build + sube beta a TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build + sube al App Store. Usa submit:true para enviar a review directamente

### ios upload_only

```sh
[bundle exec] fastlane ios upload_only
```

Sube la última .ipa sin recompilar. Usa submit:true para enviar a review

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Sube metadata ASO sin build. Usa version:X.Y.Z para versión específica

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Sube screenshots existentes al App Store Connect

### ios status

```sh
[bundle exec] fastlane ios status
```

Muestra el estado actual de la app en App Store Connect

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
