# Instalar desde el código fuente

Usa Flutter **3.41.6**, la versión fijada en la automatización del proyecto. El repositorio incluye el código fuente. Los paquetes de protocolo y análisis se obtienen de Git al resolver las dependencias.

```sh
git clone https://github.com/iamnastynash/templo.git
cd templo
flutter pub get
flutter devices
```

También puedes [descargar el ZIP](https://github.com/iamnastynash/templo/archive/refs/heads/main.zip), extraerlo y ejecutar los comandos de Flutter desde esa carpeta.

## iPhone

1. Usa un Mac con Xcode compatible con la versión de iOS del iPhone. Para iOS 26 usa Xcode 26 y consulta la [tabla de compatibilidad de Apple](https://developer.apple.com/support/xcode/).
2. Ejecuta `cp ios/Config/Signing.xcconfig.example ios/Config/Signing.xcconfig`. Rellena el Team ID, un identificador de app único y un App Group de tu equipo. Abre `ios/Runner.xcworkspace` en Xcode después de resolver las dependencias e instala los pods con `(cd ios && pod install)` si aún no aparece el workspace o faltan dependencias. Configura la firma de los targets de app, widget y reloj aplicables. La disponibilidad de capacidades como App Groups y HealthKit depende de tu equipo de Apple.
3. Conecta y desbloquea el iPhone, pulsa **Confiar** y activa el **Modo desarrollador** si Xcode lo solicita.
4. Ejecuta `flutter run --release -d ID_DEL_IPHONE`. Usa el ID que muestra `flutter devices`.

### Ajuste opcional para Xcode 16

En un iPhone compatible con el SDK de Xcode 16, aplica el ajuste local de Workmanager si el compilador marca errores de APIs de iOS 26. Desde la raíz del repositorio, después de `flutter pub get`:

```sh
mkdir -p .dart_tool/local_plugins
cp -R "${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/workmanager_apple-0.9.6" .dart_tool/local_plugins/workmanager_apple
patch -d .dart_tool/local_plugins/workmanager_apple -p1 < docs/patches/workmanager-apple-xcode16.patch
cat > pubspec_overrides.yaml <<'YAML'
dependency_overrides:
  workmanager_apple:
    path: .dart_tool/local_plugins/workmanager_apple
YAML
flutter pub get
```

Parte de una copia limpia del paquete y de una carpeta sin `pubspec_overrides.yaml`. Flutter modifica el lockfile al usar el ajuste local. Mantén ese cambio en tu máquina. En Xcode 26 puedes usar el paquete normal sin el override.

## Android

1. Instala el Android SDK con Android Studio y comprueba el entorno con `flutter doctor`. Si Flutter no generó los archivos locales del wrapper de Gradle, sigue el procedimiento de la [guía de compilación del proyecto original](https://github.com/OpenStrap/edge/blob/cd64eaa8/.github/workflows/build.yml).
2. Conecta un teléfono con depuración USB o arranca un emulador. Usa un teléfono para probar Bluetooth con una pulsera real.
3. Ejecuta `flutter run -d ID_DEL_ANDROID`. Para generar un APK local, usa `flutter build apk --release` y busca `build/app/outputs/flutter-apk/app-release.apk`. El perfil Gradle usa la clave de depuración cuando no se configura una clave de distribución.

## Emparejar y verificar

1. Ponte la banda y tenla cerca. Cierra la app que esté usando la conexión Bluetooth.
2. Abre Templo y usa el asistente inicial para elegir y emparejar la banda.
3. Comprueba el pulso en vivo y espera a que se sincronice el historial. Las métricas diarias aparecen cuando la app dispone de suficientes muestras.
4. Si se conecta pero no entrega datos, anota modelo y firmware y revisa el [informe del proyecto original](https://github.com/OpenStrap/edge/issues/673).

Para comprobar el proyecto, ejecuta `flutter test`. Para probar las funciones propias con mayor rapidez, ejecuta `flutter test test/pulso_compute_test.dart test/pulso_cardio_score_test.dart test/pulso_health_screens_test.dart test/pulso_screens_test.dart`.
