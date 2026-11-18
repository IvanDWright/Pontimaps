# PontiMaps — Resumen para la verificación (copia este archivo a otro chat)

> Fecha del resumen: 2026-11-18. **Nunca** hacer `git commit` ni modificar `mockups/`. Nombre único: **PontiMaps** (nunca "JaveRutas" ni "JaveMaps").

## 1. Qué es
App móvil Flutter ("El Waze del campus Javeriano", Bogotá): navegación peatonal a edificios y salones + reportes colaborativos anónimos. Mapa real con `flutter_map` + OpenStreetMap (sin llaves de pago). Firebase **plan Spark** (Auth + Firestore, sin Cloud Functions). Offline-first.

## 2. Estado actual (todo implementado, verificado solo con pruebas automáticas)
- `flutter analyze --no-pub`: **0 problemas**. `flutter test --no-pub`: **314 pruebas pasan**. `flutter build web --no-pub` compila.
- **NO verificado todavía:** compilación del APK, ejecución en emulador/celular, GPS real, Firebase real, `firestore.rules`.

| Fase | Contenido | Estado |
| :--- | :--- | :--- |
| 0–1 | Tema, métricas, dominio puro, A\*, catálogo OSM (36 edificios, ascensores, sótanos) | Hecho |
| 2 | Consentimiento Ley 1581, `LocationProvider` (GPS / simulado / stub BLE), router | Hecho |
| 3 | Mapa, buscador fijo, detalle, ruta, llegada ≤ 15 m, revocar GPS, origen manual (mantener pulsado) | Hecho |
| 4 | Reportes anónimos en memoria, moderación (3 negativos, +30 min, tope 180), pines, recálculo de ruta | Hecho |
| 5 | Directorio, horarios de apertura (Bogotá), horario local, «Mi próxima clase», candados de visitante, Atención (Ed. 21) y Bienestar (Ed. 41) | Hecho |
| 6 | Auth institucional, Firestore en tiempo real, panel de administrador, `firestore.rules` | Código hecho; **sin probar contra Firebase real** |
| 7 | Congestión por zonas, aviso de hora de salida (dentro de la app) | Hecho |

## 3. Cómo funciona el arranque
`Splash → Consentimiento (primera vez) → [puerta de entrada solo con Firebase] → Mapa` con barra inferior **Mapa · Directorio · Más**.
- `USE_OFFLINE_FALLBACK=true` (por defecto): todo en memoria/local, sin tocar Firebase. **Más → Perfil de demostración** cambia entre Visitante / Institucional Verificado / Administrador.
- `USE_OFFLINE_FALLBACK=false` + `android/app/google-services.json`: Firebase. Sin ese archivo la app vuelve sola al modo sin conexión.
- Otros `--dart-define`: `SIMULATE_LOCATION=true` (ubicación fija en la Plazoleta Central `4.6285, -74.0645`), `WALKING_SPEED_MPS=1.25`.

## 4. Lista de verificación funcional (hacer en emulador/celular)
1. **Consentimiento:** al abrir por primera vez sale la pantalla de ubicación; nada pide permiso del sistema antes de «Acepto activar ubicación». «No acepto» deja usar la app con origen manual.
2. **Flujo principal (≤ 3 toques, un solo «Ir»):** barra fija arriba → buscar `67-205` → resultado muestra **Edificio 67 · Piso 2** + «Acceso por ascensor disponible (múltiples ascensores)» → «Ir» → distancia, tiempo, siguiente tramo, «Detener ruta». Probar también `12-S101` (sótano) y «Evitar escaleras».
3. **GPS:** interruptor «Ubicación (GPS)» apaga el flujo y permite elegir origen; mantener pulsado el mapa fija el origen. Llegada ≤ 15 m muestra «Llegaste».
4. **Visitante:** «Modo visitante»; FAB «Reportar», «Mi próxima clase», calificar y horario muestran candado y abren el modal «Necesitas una cuenta institucional verificada».
5. **Reportes (perfil Verificado):** FAB → 3 opciones con icono + texto (`Cierre de paso`, `Fila larga`, `Alta afluencia`) → pin en el mapa → tocar pin → detalle anónimo, «Sigue ahí» / «Falso / Ya no está» (un voto por cuenta, el autor no vota el suyo). Un cierre sobre la ruta activa la recalcula.
6. **Directorio:** chips Todos/Cafeterías/Papelerías/Atención/Bienestar; estado Abierto / Cierra pronto / Cerrado en texto + color; «Ir» y «Reportar fila». Atención al Estudiante (Mo-Fr 08:00-17:00) y Bienestar (Mo-Fr 07:00-19:00).
7. **Horario (Verificado):** Más → Mi horario → agregar clase eligiendo edificio y salón del catálogo; chip «Mi próxima clase» muestra materia, hora y `Edificio · Piso · Salón`. A texto 200 % el chip se compacta a «Próx. clase HH:mm».
8. **Congestión:** chip «Congestión» muestra leyenda Baja/Media/Alta y el nivel por zona.
9. **Aviso de salida:** con una clase próxima aparece «Sal en N min hacia Edificio X · Piso Y» con «Iniciar ruta».
10. **Administrador (perfil demo):** Más → Panel de moderación → eliminar reporte, «Bloquear autor» (esa cuenta pasa a Visitante en solo lectura), publicar alerta oficial (queda fija en el mapa hasta cerrarla).
11. **Accesibilidad:** texto del sistema al 200 % sin desbordes; botones/chips/pines ≥ 48 × 48 dp.
12. **Sin red:** el catálogo y las rutas funcionan; los tiles del mapa pueden no cargar (esperado).

## 5. Estado del entorno (Windows) y pasos para compilar el APK
Detectado hoy con `flutter doctor`:
- Flutter 3.50.0 ✔, Chrome ✔, Visual Studio 2022 17.10.5 (viejo: `flutter run -d windows` falla al enlazar Firebase; **no es objetivo del proyecto**, usar Chrome o Android).
- **Android SDK 36.0.0 encontrado**, pero faltan: **`cmdline-tools`** y **aceptar licencias**.
- Android Studio ya instalado; falta instalar los plugins **Flutter** y **Dart** (aviso `FlutterRunConfigurationType not installed` → *Configure plugins…*).

Pasos pendientes:
1. Android Studio → *Settings → Languages & Frameworks → Android SDK → SDK Tools* → marcar **Android SDK Command-line Tools (latest)** → Apply.
2. Plugins Flutter y Dart (Configure plugins…).
3. En PowerShell:
```powershell
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
flutter doctor --android-licenses
flutter doctor -v
```
4. Probar y compilar (con **Modo de desarrollador** de Windows activo):
```powershell
flutter devices
flutter run -d <id> --dart-define=USE_OFFLINE_FALLBACK=true
flutter build apk --release --dart-define=USE_OFFLINE_FALLBACK=true
```
APK: `build\app\outputs\flutter-apk\app-release.apk` (firmado con clave de depuración; sirve para compartir por Drive/WhatsApp, no para Play Store).
- Si `flutter pub get` falla con `errno = 17` (caché de pub en `C:`, proyecto en `D:`): `$env:PUB_CACHE='D:\.pub-cache-pm'` antes del comando.
- Guía completa: `docs/ANDROID_APK_GUIDE.md`. Firebase: `docs/FIREBASE_SETUP.md`.

## 6. Riesgos conocidos al compilar Android (cambios hechos a ciegas)
- `android/app/build.gradle.kts`: `minSdk = 29`, firma `release` con clave de depuración (o `android/key.properties`), `proguardFiles(...)`, plugin `google-services` solo si existe `google-services.json`. `android/build.gradle.kts`: `buildscript` condicional con `com.google.gms:google-services:4.4.4`. Si Gradle falla, pegar el error completo.
- AGP 9.3.1 / Kotlin 2.4.20 (versiones nuevas): posible incompatibilidad de algún plugin.
- Manifiesto: `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`.

## 7. Pendientes conocidos (no son errores)
- `firestore.rules` **sin probar** (hacer los 12 casos de `docs/FIREBASE_SETUP.md` con el Emulator Suite) y Firebase nunca ejecutado contra un proyecto real.
- Notificaciones del sistema: falta `flutter_local_notifications` detrás de `NotificationScheduler` (hoy es un aviso dentro de la app).
- Falta: recuperar contraseña (S06), recálculo al desviarse > 25 m (RF-NAV-06), `firebase_options.dart` para iOS/web, calibración del tiempo estimado en campo (±1 min), levantar ascensores/rampas de los edificios "sin confirmar".
- Datos: salones son de ejemplo salvo `67-205`; en OSM el edificio "Gabriel Giraldo" es el **3**.
- Privacidad: nunca se guarda historial de posiciones; el `authorHash` (SHA-256 del `uid`) vive solo en `reportAuthors` y nunca se muestra.

## 8. Mapa de archivos clave
- Dominio: `lib/domain/routing/grafo_campus.dart` (A\*), `domain/search/`, `domain/services/` (`auth_guard`, `moderation_service`, `opening_hours`, `next_class`, `congestion_service`, `departure_planner`).
- Datos: `lib/data/` (`campus_cartography`, `campus_osm_data`, `location_service`, `consent_repository`, `reports_repository`, `places_repository`, `schedule_repository`, `auth_repository`, `firebase_auth_repository`, `firestore_repositories`, `admin_repository`, `official_alerts_repository`, `app_session`, `map_sdk_adapter`).
- UI: `lib/presentation/screens/` (`map_home_screen`, `directory_screen`, `schedule_screen`, `more_screen`, `auth_screens`, `admin_panel_screen`, `permission_screen`), `widgets/`.
- Arranque: `lib/main.dart`, `lib/app.dart`, `lib/core/bootstrap.dart`, `lib/core/routing/`.
- Backend: `firestore.rules`, `firebase.json`. Docs: `docs/` (`REQUIREMENTS.md`, `ARCHITECTURE.md` §7 tiene el estado por fases, `USER_PATHS.md`).
- Pruebas: `test/` (domain, data, presentation, helpers).

## 9. Qué pedirle al otro chat
"Verifica la app en Android: ayúdame a dejar `flutter doctor` en verde, compilar `flutter build apk --release --dart-define=USE_OFFLINE_FALLBACK=true`, instalarla y recorrer la lista de la sección 4. Cada fallo me lo reportas con el mensaje exacto; no hagas `git commit` ni toques `mockups/`."
