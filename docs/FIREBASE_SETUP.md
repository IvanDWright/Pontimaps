# Configurar Firebase (plan gratuito Spark) para PontiMaps

> **Estado de verificación.** El código de Firebase (`FirebaseAuthRepository`, `FirestoreReportsRepository`, `FirestoreAdminRepository`, `FirestoreOfficialAlertsRepository`) y `firestore.rules` están escritos y la lógica de los repositorios se prueba con `fake_cloud_firestore`, pero **nunca se han ejecutado contra un proyecto real** ni contra el emulador. Las reglas **no se han probado**: haz los casos de la sección 6 antes de desplegarlas.

Sin Cloud Functions: toda escritura es del cliente y **las reglas son la autoridad** (`docs/REQUIREMENTS.md` §4).

## 1. Crear el proyecto

1. [console.firebase.google.com](https://console.firebase.google.com) → *Agregar proyecto* (el ID por defecto del código es `pontimaps-puj`; es solo informativo).
2. **Authentication → Método de acceso → Correo electrónico/contraseña**: habilitar (sin "enlace por correo" ni otros proveedores).
3. **Authentication → Plantillas → Verificación de correo**: personaliza el texto en español (la verificación usa el **enlace nativo**, `sendEmailVerification()`).
4. **Firestore Database → Crear base de datos** en modo de producción.

## 2. Registrar la app Android

1. *Configuración del proyecto → Agregar app → Android*, con el nombre de paquete `co.edu.javeriana.pontimaps_app`.
2. Descarga `google-services.json` y cópialo en `android/app/google-services.json`. **No se sube a Git** (está en `.gitignore`).
3. Con ese archivo presente, el `build.gradle.kts` aplica solo el plugin `com.google.gms.google-services`.

(iOS y web necesitan `flutterfire configure` y un `firebase_options.dart`; no están configurados.)

## 3. Desplegar las reglas

```powershell
npm install -g firebase-tools
firebase login
firebase use --add
firebase deploy --only firestore:rules
```

## 4. Colecciones

| Colección | Qué guarda | Quién escribe |
| :--- | :--- | :--- |
| `reports/{id}` | Reporte **público**, sin autor | Cuenta verificada y activa |
| `reports/{id}/votes/{authorHashVotante}` | Voto (`valor` ±1). El id impide un segundo voto | Cuenta verificada y activa |
| `reportAuthors/{id}` | `authorHash` privado del autor | El autor (mismo *batch* que el reporte) |
| `officialAlerts/{id}` | Alertas oficiales fijas | Solo administrador |
| `users/{uid}` | `rol`, `estado`, `authorHash`, `consent`, `ultimoReporteEn` | El dueño (sin tocar rol/estado/hash); el administrador solo `estado` |
| `adminActions/{id}` | Bitácora de moderación (mejor esfuerzo) | Solo administrador |

> Los nombres siguen `docs/REQUIREMENTS.md` §4.1 (`users`, `reports`, `reportAuthors`, `officialAlerts`). Se mantuvieron en inglés para no contradecir ese documento; los términos en español `usuarios` / `reportes` / `votos` del pedido equivalen a `users` / `reports` / `reports/{id}/votes`.

## 5. Asignar un administrador

`rol: admin` **solo se asigna a mano**: Firestore → `users` → el documento del usuario (su `uid` está en Authentication) → editar `rol` = `admin`. Ningún cliente puede hacerlo (las reglas lo impiden) y la app no tiene una pantalla para crearlo.

Con `rol: admin` y el correo verificado aparece **Más → Panel de moderación**: eliminar reportes, **Bloquear autor** (pone `estado = 'bloqueado'` a la cuenta con ese `authorHash`; la app de esa persona pasa a modo Visitante en solo lectura) y publicar alertas oficiales.

## 6. Probar las reglas con el Emulator Suite (pendiente)

```powershell
firebase emulators:start --only firestore
```

Casos mínimos (todos deben comportarse como se indica):

1. Visitante sin sesión intenta crear un reporte → **denegado**.
2. Cuenta sin verificar intenta reportar → **denegado**.
3. Correo de otro dominio intenta reportar → **denegado**.
4. Usuario bloqueado intenta votar → **denegado**.
5. Un cliente intenta cambiar su `rol`, `estado` o `authorHash` → **denegado**.
6. Segundo voto de la misma cuenta al mismo reporte → **denegado**.
7. El autor vota su propio reporte → **denegado**.
8. Lectura de `reportAuthors` por otro usuario → **denegada**; por el administrador y por el autor → **permitida**.
9. Reporte con `expiraEn` distinto de `creadoEn + 60 min` → **denegado**.
10. Dos reportes seguidos dentro de 60 s → el segundo **denegado**.
11. Un cliente no administrador publica o borra una alerta oficial → **denegado**.
12. Un administrador elimina un reporte, publica una alerta y bloquea a un usuario no administrador → **permitido**; intenta bloquear a otro administrador o a sí mismo → **denegado**.

## 7. Expiración (TTL) y cuotas del plan Spark

- Políticas TTL de Firestore (*Firestore → Datos → TTL*): `reports.expiraEn` y `reportAuthors.borrarEn`. Pueden tardar hasta ~24 h: **el cliente siempre filtra por `expiraEn`**.
- Cada escritura valida con `get()`/`exists()` sobre `users/{uid}` y `reportAuthors/{id}`: **cuentan como lecturas** de la cuota gratuita. Revisa los límites vigentes antes de un evento grande (D-18).
- Tolerancia de reloj: `creadoEn` debe estar a ±60 s de `request.time` y `expiraEn − creadoEn` debe ser exactamente 60 min.

## 8. Cambiar entre modo sin conexión y Firebase

| Compilación | Resultado |
| :--- | :--- |
| `--dart-define=USE_OFFLINE_FALLBACK=true` (por defecto) | Todo en memoria/local; no toca Firebase |
| `--dart-define=USE_OFFLINE_FALLBACK=false` + `google-services.json` | Firebase Auth + Firestore; antes del mapa aparece la puerta de entrada (S02) |
| `--dart-define=USE_OFFLINE_FALLBACK=false` **sin** `google-services.json` | Firebase no inicia: la app vuelve sola al modo sin conexión |
