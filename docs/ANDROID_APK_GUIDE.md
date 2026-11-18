# Guía corta: abrir PontiMaps en Android Studio y generar el APK

> **Estado de verificación.** El proyecto se preparó para Android (API 29+), pero en el equipo donde se desarrolló **no hay Android SDK**, así que `flutter build apk` **no se ha ejecutado** todavía. Sigue esta guía y, si algo falla, anota el mensaje: casi siempre es una licencia o una versión del SDK.

## 1. Requisitos (una sola vez)

1. **Android Studio** (última versión estable). En el asistente de primer arranque deja marcados *Android SDK*, *Android SDK Command-line Tools* y *Android Virtual Device*.
2. En *Settings → Languages & Frameworks → Android SDK* instala **Android 14 o 15 (API 34/35)**.
3. **Flutter** ya instalado y en el `PATH`. En Windows activa el **Modo de desarrollador** (`start ms-settings:developers`): los plugins necesitan *symlinks*.
4. Apunta Flutter al SDK y acepta las licencias:

```powershell
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
flutter doctor --android-licenses
flutter doctor -v
```

`Android toolchain` debe quedar en verde.

> Si `flutter pub get` falla con `errno = 17` (la caché de pub está en `C:` y el proyecto en `D:`), define `PUB_CACHE` en una carpeta de la misma unidad que el proyecto, por ejemplo `D:\.pub-cache`.

## 2. Abrir el proyecto

1. *File → Open* y elige la carpeta del proyecto (`pontimaps_app`), no la subcarpeta `android`.
2. Espera a que termine *Gradle sync*. Instala los plugins **Flutter** y **Dart** si Android Studio lo pide.
3. Primera sincronización: puede tardar varios minutos (descarga Gradle y el SDK).

## 3. Probar en emulador o celular

**Emulador:** *Device Manager → Create device* (Pixel, Android 14+). **Celular:** activa *Opciones de desarrollador → Depuración USB* y conéctalo.

```powershell
flutter devices
flutter run -d <id-del-dispositivo> --dart-define=USE_OFFLINE_FALLBACK=true
```

- **Ubicación en el emulador:** `...` (Extended Controls) → *Location* → busca "Pontificia Universidad Javeriana, Bogotá" (`4.6285, -74.0645`) → *Save point* → *Set location*.
- Sin GPS (o para una demo) puedes forzar la Plazoleta Central: `--dart-define=SIMULATE_LOCATION=true`.
- La velocidad peatonal base es 1,25 m/s; se cambia con `--dart-define=WALKING_SPEED_MPS=1.1`.
- En modo demostración, **Más → Perfil de demostración** cambia entre Visitante, Institucional Verificado y Administrador.

## 4. Generar el APK para compartir

```powershell
flutter build apk --release --dart-define=USE_OFFLINE_FALLBACK=true
```

El archivo queda en:

```
build\app\outputs\flutter-apk\app-release.apk
```

- Está firmado con la **clave de depuración** (sirve para probar y compartir, **no** para Google Play). Para firmar con tu propio almacén crea `android/key.properties` (no se sube a Git) con `keyAlias`, `keyPassword`, `storeFile` y `storePassword`; el `build.gradle.kts` lo detecta solo.
- Para un APK más pequeño por arquitectura: `flutter build apk --split-per-abi ...`.

## 5. Compartir e instalar

1. Sube `app-release.apk` a Drive (o envíalo por WhatsApp como documento).
2. En el celular: abre el archivo → permite *Instalar apps desconocidas* para ese origen → instalar.
3. Al abrir la app verás primero la pantalla de **consentimiento de ubicación** (Ley 1581); puede rechazarla y elegir el origen a mano.

## 6. Con Firebase (Fase 6)

Mientras no exista `android/app/google-services.json`, la app corre sin conexión aunque pases `USE_OFFLINE_FALLBACK=false` (vuelve sola al modo local). Para activar Firebase sigue `docs/FIREBASE_SETUP.md` y compila con:

```powershell
flutter build apk --release --dart-define=USE_OFFLINE_FALLBACK=false
```

## 7. Problemas frecuentes

| Síntoma | Qué hacer |
| :--- | :--- |
| `No Android SDK found` | Paso 1.4: `flutter config --android-sdk ...` |
| `Building with plugins requires symlink support` | Activa el Modo de desarrollador de Windows |
| `Android license status unknown` | `flutter doctor --android-licenses` y acepta todo con `y` |
| R8 / `Missing class com.google.android.play.core...` | Ya se silencia en `android/app/proguard-rules.pro`; si aparece otra clase, añade `-dontwarn` para ella |
| `minSdkVersion` de un plugin mayor que 29 | Sube `minSdk` en `android/app/build.gradle.kts` solo si es imprescindible |
| La app abre en blanco con `USE_OFFLINE_FALLBACK=false` | Falta `google-services.json`: se usa el modo sin conexión; revisa `docs/FIREBASE_SETUP.md` |

## 8. Notificaciones de hora de salida

El permiso `POST_NOTIFICATIONS` ya está declarado, pero hoy la alerta "Sal en N min…" se muestra como **aviso dentro de la app** con el botón *Iniciar ruta* (`InAppNotificationScheduler`). Las notificaciones del sistema requieren añadir `flutter_local_notifications` (y el *core library desugaring* de Gradle) detrás de la interfaz `NotificationScheduler`; no se añadió porque no se pudo verificar el build de Android.
