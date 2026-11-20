# PontiMaps

**El Waze del Campus Javeriano** — Aplicación móvil desarrollada en Flutter para la navegación peatonal interna hacia edificios, salones y servicios de la Pontificia Universidad Javeriana (Bogotá), con reportes colaborativos en tiempo real, accesibilidad para movilidad reducida y privacidad por diseño.

| Dato | Detalle |
| :--- | :--- |
| **Producto** | PontiMaps (marca gráfica: *La Pontimaps*) |
| **Paquete / ID** | `co.edu.javeriana.pontimaps_app` |
| **Plataforma** | Android 10+ (API 29+) · Flutter / Dart (`^3.14.0`) |
| **Backend** | Firebase Auth + Cloud Firestore (plan gratuito Spark, sin Cloud Functions) |
| **Normativa** | WCAG 2.2 (contraste AA, texto hasta 200 %, zonas táctiles ≥ 48 × 48 dp) · NTC 4143 · Ley 1581 de 2012 |
| **Asignatura** | Innovación y Diseño de Producto — Pregrado de Ingeniería (2026-2) |

---

## Funcionalidades principales

- **Navegación peatonal en ≤ 3 toques:** buscador fijo superior por edificio (número o nombre), salón o servicio, cálculo de ruta peatonal sobre grafo del campus con motor **A\*** y tiempo estimado de llegada.
- **Accesibilidad vertical (NTC 4143):** opción *"Evitar escaleras"* integrada con catálogo verificado de edificios, pisos, sótanos, rampas y disponibilidad de ascensores (`docs/edificios_ascensores.json`).
- **Reportes colaborativos anónimos:** publicación de alertas (*Cierre de paso*, *Fila larga*, *Alta afluencia*) con expiración automática a 60 minutos, votación comunitaria (ocultamiento automático a los 3 votos negativos) y anonimato visual (`authorHash` privado solo en `reportAuthors`).
- **Mapa de congestión:** visualización de niveles de afluencia (*Baja*, *Media*, *Alta*) integrada al campus.
- **Rutina académica y directorio:** gestión de horario con acceso en 1 toque a *"Mi próxima clase"*, alertas de salida y directorio de servicios del campus (cafeterías, papelerías, atención al estudiante y bienestar).
- **Control de acceso por roles:** modo **Visitante** (solo lectura, sin sesión en la nube), **Institucional verificado** (`@javeriana.edu.co` con verificación nativa de correo) y **Administrador** (asignado exclusivamente desde la consola de Firebase, con panel de moderación y alertas oficiales).
- **Privacidad por diseño (Ley 1581 de 2012):** consentimiento informado previo antes de solicitar permisos de GPS, interruptor para pausar/revocar la ubicación en cualquier momento y procesamiento de coordenadas únicamente en memoria volátil (nunca se almacena historial de recorridos).

---

## Stack tecnológico

- **Frontend móvil:** Flutter, Dart, `flutter_riverpod` (estado), `go_router` (navegación), `flutter_map` + `latlong2` (cartografía OpenStreetMap), `geolocator` + `permission_handler`, `shared_preferences`.
- **Backend (opcional / producción):** `firebase_core`, `firebase_auth`, `cloud_firestore` con validación estricta mediante `firestore.rules`.
- **Pruebas:** `flutter_test`, `fake_cloud_firestore`, `firebase_auth_mocks` y suite de pruebas de reglas en Node.js con **Firebase Emulator Suite**.

---

## Requisitos previos

- **Flutter SDK** con Dart `^3.14.0` ([Guía oficial de instalación](https://docs.flutter.dev/get-started/install)).
- **Android Studio / Android SDK** (API 29 o superior) y un emulador o dispositivo Android físico con depuración USB habilitada.
- **Git**.
- *(Opcional)* **Node.js 18+** y **Java 21+** para ejecutar el prototipo web en `mockups/` o las pruebas de `firestore.rules` con el Firebase Emulator Suite.

Verifica que tu entorno de Flutter esté listo:

```bash
flutter doctor
```

---

## Instalación y uso desde cero

### 1. Clonar el repositorio

```bash
git clone https://github.com/IvanDWright/Pontimaps.git
cd Pontimaps
```

### 2. Instalar dependencias de Flutter

```bash
flutter pub get
```

### 3. Ejecutar la aplicación (modo demostración sin Firebase)

Por defecto, la app arranca en **modo sin conexión / demostración** (`USE_OFFLINE_FALLBACK=true`), utilizando el catálogo cartográfico local del campus y repositorios en memoria. No necesitas configurar llaves ni cuentas de Firebase para probar todas las pantallas y flujos.

```bash
flutter run
```

Si estás probando en un emulador o quieres fijar tu ubicación dentro del campus (Plazoleta Central) sin depender del GPS real:

```bash
flutter run --dart-define=SIMULATE_LOCATION=true
```

### 4. Ejecutar con Firebase (opcional)

Para conectar la app a un proyecto real de Firebase (Authentication + Cloud Firestore en plan Spark):

1. Sigue la guía paso a paso en [docs/FIREBASE_SETUP.md](./docs/FIREBASE_SETUP.md) para crear el proyecto, habilitar correo/contraseña y desplegar `firestore.rules`.
2. Descarga `google-services.json` desde la consola de Firebase y colócalo en `android/app/google-services.json` *(este archivo está ignorado por Git y nunca debe subirse al repositorio)*.
3. Ejecuta la app desactivando el modo sin conexión:

```bash
flutter run --dart-define=USE_OFFLINE_FALLBACK=false --dart-define=FIREBASE_PROJECT_ID=pontimaps-puj
```

> Si ejecutas con `USE_OFFLINE_FALLBACK=false` pero no existe `google-services.json`, la app regresa automáticamente al modo sin conexión.

### 5. Generar el APK de Android

```bash
flutter build apk --release
```

El archivo generado quedará en `build/app/outputs/flutter-apk/app-release.apk`.

---

## Parámetros de ejecución (`--dart-define`)

Puedes configurar el comportamiento de la app en tiempo de compilación sin guardar secretos en el código (también admite `--dart-define-from-file=dart_defines.json`, usando `.env.example` como referencia):

| Parámetro | Valor por defecto | Descripción |
| :--- | :--- | :--- |
| `USE_OFFLINE_FALLBACK` | `true` | `true`: modo demostración local en memoria. `false`: conecta con Firebase Auth y Firestore. |
| `FIREBASE_PROJECT_ID` | `pontimaps-puj` | Identificador informativo del proyecto de Firebase. |
| `SIMULATE_LOCATION` | `false` | `true`: usa un punto fijo en el campus (Plazoleta Central) en lugar del GPS del dispositivo. |
| `WALKING_SPEED_MPS` | `1.25` | Velocidad peatonal base en m/s (~4,5 km/h) usada para estimar los minutos de recorrido. |

---

## Pruebas y análisis estático

### Flutter (análisis estático y suite de pruebas)

```bash
flutter analyze
flutter test
```

La suite incluye **314 pruebas automatizadas** que cubren dominio puro (grafo, motor A\*, accesibilidad vertical, anonimato y moderación), contraste WCAG 2.2, escala de texto al 200 % y flujos completos de interfaz.

### Reglas de seguridad de Firestore (Emulator Suite)

Requiere Node.js, Java 21+ y `firebase-tools`:

```bash
npm --prefix tool/firestore_rules_test install
firebase emulators:exec --only firestore --project demo-pontimaps "node --test --test-concurrency=1 tool/firestore_rules_test/firestore.rules.test.mjs"
```

Ejecuta **27 pruebas** contra `firestore.rules` validando permisos por rol, verificación institucional, anonimato de autoría, límites de frecuencia y moderación administrativa.

---

## Prototipo visual interactivo (`mockups/`)

El repositorio incluye el prototipo interactivo de alta fidelidad (Iteración V3, `360 × 800 dp`) desarrollado en React + TypeScript + Vite:

```bash
cd mockups
npm install
npm run dev
```

Consulta más detalles en [mockups/README.md](./mockups/README.md).

---

## Estructura del repositorio

```text
Pontimaps/
├── android/                     # Configuración nativa Android (co.edu.javeriana.pontimaps_app, minSdk 29)
├── docs/                        # Documentación técnica y datos cartográficos
│   ├── README.md                # Índice general de documentación
│   ├── ARCHITECTURE.md          # Arquitectura de 3 capas, 12 módulos, 7 TADs y privacidad
│   ├── REQUIREMENTS.md          # Requerimientos funcionales (RF), no funcionales (RNF) y modelo Firestore
│   ├── USER_PATHS.md            # Flujos de usuario paso a paso (Paths 0A, 0B y 1–6)
│   ├── FIREBASE_SETUP.md        # Guía de configuración de Firebase (plan Spark) y Emulator Suite
│   ├── GRAPH_REPORT.md          # Reporte estructural del repositorio
│   ├── javeriana_osm.geojson    # Cartografía OpenStreetMap del campus PUJ (Bogotá)
│   └── edificios_ascensores.json # Catálogo verificado de edificios, pisos y ascensores (NTC 4143)
├── lib/                         # Código fuente Flutter (Arquitectura de 3 capas)
│   ├── core/                    # Configuración (AppConfig), tema (PontiMapsTheme), métricas y utilidades
│   ├── data/                    # Cartografía local, ubicación GPS, sesión y repositorios (local / Firebase)
│   ├── domain/                  # Motor de enrutamiento A*, búsqueda, congestión y Auth Guard
│   ├── models/                  # TADs y modelos de dominio
│   └── presentation/            # Pantallas (screens) y componentes reutilizables (widgets)
├── mockups/                     # Prototipo visual interactivo V3 (Vite + React + TypeScript)
├── test/                        # Suite de pruebas unitarias y de widgets (Flutter)
├── tool/firestore_rules_test/   # Suite de pruebas para firestore.rules con Firebase Emulator Suite
├── firestore.rules              # Reglas de seguridad de Cloud Firestore
├── firebase.json                # Configuración del emulador de Firestore
├── .env.example                 # Plantilla de variables locales de referencia
└── pubspec.yaml                 # Dependencias y metadatos del proyecto Flutter
```

---

## Documentación

- [Índice de documentación](./docs/README.md)
- [Arquitectura del sistema](./docs/ARCHITECTURE.md)
- [Requerimientos funcionales y no funcionales](./docs/REQUIREMENTS.md)
- [Flujos de usuario (User Paths)](./docs/USER_PATHS.md)
- [Configuración de Firebase y Emulator Suite](./docs/FIREBASE_SETUP.md)
- [Guía del prototipo visual V3](./mockups/README.md)

---

## Equipo

- Juan Pablo Morea
- Juan Pablo Gómez
- Santiago Corredor
- Iván Wright
