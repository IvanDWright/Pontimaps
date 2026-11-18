# PontiMaps (`pontimaps_app`)

**El Waze del Campus Javeriano** — Aplicación móvil nativa desarrollada en Flutter para navegación peatonal interna hacia edificios y salones de la Pontificia Universidad Javeriana (Bogotá), con reportes colaborativos en tiempo real (cierres, filas, alta afluencia).

* **Nombre Oficial Unificado:** **PontiMaps** (marca gráfica: **La Pontimaps**).
* **Organización / Paquete:** `co.edu.javeriana.pontimaps_app`
* **Equipo del Proyecto:** Juan Pablo Morea, Juan Pablo Gómez, Santiago Corredor, Iván Wright.
* **Asignatura:** Innovación y Diseño de Producto (Pregrado de Ingeniería, 2026-2).

## Estructura del Repositorio

```text
pontimaps_app/
├── docs/                      # Documentación técnica y de ingeniería del proyecto
│   ├── README.md              # Índice general de documentación
│   ├── ARCHITECTURE.md        # Arquitectura de 3 Capas, 12 Módulos, estructura lib/ y privacidad
│   ├── USER_PATHS.md          # Flujos de usuario paso a paso (Paths 1-8) sincronizados con el Mockup V3
│   ├── REQUIREMENTS.md        # Especificación completa de RF, RNF, Firestore y Cloud Functions
│   ├── GRAPH_REPORT.md        # Reporte del grafo de código
│   ├── javeriana_osm.geojson  # Exportación GeoJSON de OpenStreetMap del campus Javeriano
│   └── edificios_ascensores.json # Catálogo de edificios, pisos, ascensores y accesibilidad (NTC 4143)
├── mockups/                   # Prototipo visual interactivo de alta fidelidad (Iteración V3)
│   ├── README.md              # Guía del mockup y cómo ejecutarlo
│   ├── package.json           # Configuración Vite + React + TypeScript
│   ├── index.html             # Entrada web del mockup
│   └── src/
│       ├── App.tsx            # Pantallas y lógica interactiva del prototipo V3
│       ├── index.css          # Sistema de diseño (360x800dp, colores PUJ, WCAG 2.2)
│       └── main.tsx           # Bootstrap de React
└── lib/                       # Código fuente de la aplicación móvil en Flutter (3 Capas)
    ├── core/                  # Tema (PontiMapsTheme), constantes (layout_metrics) y utilidades
    ├── data/                  # Cartografía semilla, GPS/BLE y repositorio de reportes
    ├── domain/                # Modelos de dominio y motor de rutas A* / Dijkstra
    └── presentation/          # Pantallas (screens) y componentes (widgets)
```

## Enlaces Rápidos

* **Documentación (`docs/`):** [Índice](./docs/README.md) · [Arquitectura](./docs/ARCHITECTURE.md) · [User Paths](./docs/USER_PATHS.md) · [Requerimientos](./docs/REQUIREMENTS.md)
* **Mockup Visual V3 (`mockups/`):** [Guía del Mockup](./mockups/README.md) · [App.tsx](./mockups/src/App.tsx) · [index.css](./mockups/src/index.css)
