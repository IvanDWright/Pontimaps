# Documentación del Proyecto — PontiMaps (`La Pontimaps`)

Índice central de la documentación técnica, arquitectónica, de flujos de usuario y de diseño de **PontiMaps**:

## Documentos Principales

1. **[Arquitectura del Sistema (`ARCHITECTURE.md`)](./ARCHITECTURE.md)**
   * Arquitectura de 3 Capas (`Presentation`, `Domain`, `Data`) y los 12 Módulos del sistema.
   * Diagrama de componentes e integración Offline-First.
   * Estructura detallada de carpetas y archivos (`lib/`).
   * Arquitectura de privacidad por diseño (Ley 1581 de 2012) y control de acceso por roles (`visitor`, `verified`, `admin`).

2. **[Flujos de Usuario y Pantallas — User Paths (`USER_PATHS.md`)](./USER_PATHS.md)**
   * Recorridos paso a paso (User Paths 1 al 8) sincronizados 1:1 con el Mockup Visual V3:
     * Entrada, Login, Registro Institucional (5 reglas de contraseña) y Modo Visitante.
     * Consentimiento Informado de Ubicación GPS (Ley 1581).
     * Búsqueda ($\le 3$ toques), Ruta Peatonal Activa y opción *"Evitar escaleras"*.
     * Acceso en 1 toque a *"Mi próxima clase"* y alertas de salida.
     * Reportes colaborativos anónimos (TTL 60 min) y moderación comunitaria (3 votos negativos).
     * Capa de calor de congestión, Directorio de Servicios y Panel de Administración.

3. **[Documento de Requerimientos (`REQUIREMENTS.md`)](./REQUIREMENTS.md)**
   * Especificación detallada de Requerimientos Funcionales (`RF-*`), No Funcionales (`RNF-*`), modelo de datos en Cloud Firestore, Security Rules y Cloud Functions.

4. **[Reporte de Grafo del Repositorio (`GRAPH_REPORT.md`)](./GRAPH_REPORT.md)**
   * Análisis estructural generado con Graphify sobre los nodos y comunidades del código.

5. **[Cartografía Base OpenStreetMap (`javeriana_osm.geojson`)](./javeriana_osm.geojson)**
   * Exportación GeoJSON del campus de la Pontificia Universidad Javeriana (Bogotá) para edificios, polígonos y senderos peatonales.

6. **[Catálogo de Edificios, Pisos y Ascensores (`edificios_ascensores.json`)](./edificios_ascensores.json)**
   * Matriz verificada de 23 edificios del campus PUJ cruzada con `osmWayId`, número de pisos, disponibilidad de ascensor (`tieneAscensor`, `tieneMultiplesAscensores`) y accesibilidad para movilidad reducida (NTC 4143).

## Mockups y Prototipo Visual

* **[Mockup Visual Interactivo V3 (`../mockups/`)](../mockups/README.md)**
  * Prototipo de alta fidelidad en React + TypeScript + CSS (`360x800 dp`) con todas las pantallas del flujo de **PontiMaps**.
