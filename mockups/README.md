# Mockup Visual Interactivo V3 — PontiMaps (`La Pontimaps`)

Esta carpeta contiene el prototipo visual de alta fidelidad (Iteración V3) de **PontiMaps**, que sirve como especificación de diseño y comportamiento UI/UX para la aplicación Flutter en `lib/`.

## Estructura del Mockup

* [`src/App.tsx`](./src/App.tsx) — Componente completo interactivo con todos los flujos de pantallas:
  * **Flujo de Entrada y Autenticación:** Gate (`Navega tu campus`), Inicio de Sesión (`@javeriana.edu.co`), Registro con validación de fortaleza de contraseña (5 reglas) y Ley 1581, Verificación de correo Firebase (temporizador de 60s), y Pantalla de Consentimiento Informado de Ubicación GPS.
  * **Mapa Principal y Navegación:** Barra buscadora fija superior, chip de *"Mi próxima clase"* con alerta de salida según congestión, pines de edificios/servicios, capa de calor de congestión (`Baja` / `Media` / `Alta`), hoja inferior de detalle (`Edificio + Piso`, toggle *"Evitar escaleras"*, botón `"Ir"`), tarjeta de ruta activa paso a paso y confirmación de llegada.
  * **Reportes Colaborativos (Waze Javeriano):** FAB `"Reportar"`, modal con iconos y etiquetas (`Cierre de paso`, `Fila larga`, `Alta afluencia`), votación comunitaria (`Sigue ahí` / `Falso / Ya no está`, ocultamiento a los 3 votos negativos) y expiración a 60 minutos.
  * **Directorio del Campus:** Filtro por categorías (`Todos`, `Cafeterías`, `Papelerías`, `Atención`, `Bienestar`), estado (`Abierto`, `Cierra pronto`, `Cerrado`) y nivel de fila.
  * **Más / Ajustes y Administración:** Switch en vivo para pausar/revocar el GPS, selector de modo de demostración (`Visitante`, `Verificado`, `Administrador`) y panel restringido de Administración (bloqueo de usuarios con motivo obligatorio y creación de alertas oficiales fijas).
* [`src/index.css`](./src/index.css) — Sistema de diseño visual (`360x800 dp`, paleta `#002D72` / `#F2A900` / `#F8F9FA`, tipografía `Manrope` + `DM Sans` en `22/16/12 sp`, zonas táctiles mínimas de `48x48 dp`).
* [`src/main.tsx`](./src/main.tsx) — Punto de entrada de React.

## Cómo ejecutar el Mockup en el navegador (Opcional)

```bash
cd mockups
npm install
npm run dev
```
