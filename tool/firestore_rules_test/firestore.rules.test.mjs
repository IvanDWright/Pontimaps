// Pruebas de `firestore.rules` (docs/FIREBASE_SETUP.md §6, casos 1 a 12 + caminos felices).
//
// Ejecutar desde la raíz del repo (arranca y apaga el emulador solo):
//   firebase emulators:exec --only firestore --project demo-pontimaps "node --test --test-concurrency=1 tool/firestore_rules_test"
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { Timestamp, doc, getDoc, setDoc, deleteDoc, updateDoc, writeBatch } from 'firebase/firestore';

const MIN = 60 * 1000;
const H = (c) => c.repeat(64); // authorHash de 64 caracteres (SHA-256 en hex)
const HASH = { alice: H('a'), bob: H('b'), carol: H('c'), admin: H('d'), admin2: H('e'), dave: H('f') };

let env;

const ctx = (uid, { email = `${uid}@javeriana.edu.co`, verified = true } = {}) =>
  env.authenticatedContext(uid, { email, email_verified: verified }).firestore();
const db = (uid, opciones) => ctx(uid, opciones);
const anon = () => env.unauthenticatedContext().firestore();

/** Siembra datos sin pasar por las reglas. */
async function sembrar() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (contexto) => {
    const f = contexto.firestore();
    const perfil = (hash, extra = {}) => ({
      rol: 'estudiante',
      estado: 'activo',
      authorHash: hash,
      createdAt: Timestamp.now(),
      ...extra,
    });
    await setDoc(doc(f, 'users/alice'), perfil(HASH.alice));
    await setDoc(doc(f, 'users/bob'), perfil(HASH.bob));
    await setDoc(doc(f, 'users/carol'), perfil(HASH.carol, { estado: 'bloqueado' }));
    await setDoc(doc(f, 'users/dave'), perfil(HASH.dave));
    await setDoc(doc(f, 'users/admin'), perfil(HASH.admin, { rol: 'admin' }));
    await setDoc(doc(f, 'users/admin2'), perfil(HASH.admin2, { rol: 'admin' }));
    // Un reporte vigente de alice, listo para votar / moderar.
    const ahora = Date.now();
    await setDoc(doc(f, 'reports/r1'), {
      tipo: 'fila',
      lat: 4.6285,
      lng: -74.0645,
      creadoEn: Timestamp.fromMillis(ahora),
      expiraEn: Timestamp.fromMillis(ahora + 60 * MIN),
      confirmaciones: 0,
      reportesNegativos: 0,
    });
    await setDoc(doc(f, 'reportAuthors/r1'), {
      authorHash: HASH.alice,
      borrarEn: Timestamp.fromMillis(ahora + 120 * MIN),
    });
  });
}

/** Reporte nuevo válido (creadoEn = ahora, expiraEn = +60 min exactos). */
function reporteValido(extra = {}) {
  const ahora = Date.now();
  return {
    tipo: 'cierre',
    idAristaAfectada: null,
    lat: 4.6285,
    lng: -74.0645,
    creadoEn: Timestamp.fromMillis(ahora),
    expiraEn: Timestamp.fromMillis(ahora + 60 * MIN),
    confirmaciones: 0,
    reportesNegativos: 0,
    ...extra,
  };
}

/** Lo mismo que hace `FirestoreReportsRepository.crear`: reporte + autoría + ultimoReporteEn. */
function crearReporte(f, uid, hash, id, datos = reporteValido()) {
  const b = writeBatch(f);
  b.set(doc(f, 'reports', id), datos);
  b.set(doc(f, 'reportAuthors', id), {
    authorHash: hash,
    borrarEn: Timestamp.fromMillis(datos.expiraEn.toMillis() + 60 * MIN),
  });
  b.update(doc(f, 'users', uid), { ultimoReporteEn: Timestamp.now() });
  return b.commit();
}

/** Voto como en `FirestoreReportsRepository.calificar`: voto + contadores del reporte. */
async function votar(f, hash, valor, idReporte = 'r1') {
  // Leemos el reporte desde el servidor con reglas desactivadas para calcular expiraEn.
  let actual;
  await env.withSecurityRulesDisabled(async (c) => {
    actual = (await getDoc(doc(c.firestore(), 'reports', idReporte))).data();
  });
  const b = writeBatch(f);
  b.set(doc(f, 'reports', idReporte, 'votes', hash), { valor, en: Timestamp.now() });
  if (valor === 1) {
    const prorroga = Math.min(actual.creadoEn.toMillis() + 180 * MIN, actual.expiraEn.toMillis() + 30 * MIN);
    b.update(doc(f, 'reports', idReporte), {
      confirmaciones: actual.confirmaciones + 1,
      expiraEn: Timestamp.fromMillis(prorroga),
    });
  } else {
    b.update(doc(f, 'reports', idReporte), { reportesNegativos: actual.reportesNegativos + 1 });
  }
  return b.commit();
}

describe('firestore.rules', () => {
  before(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-pontimaps',
      firestore: { rules: readFileSync('firestore.rules', 'utf8') },
    });
  });
  after(async () => env?.cleanup());
  beforeEach(sembrar);

  describe('caminos felices', () => {
    it('lectura pública de reportes y alertas (incluye visitante sin sesión)', async () => {
      await assertSucceeds(getDoc(doc(anon(), 'reports/r1')));
      await assertSucceeds(getDoc(doc(anon(), 'officialAlerts/x')));
    });

    it('cuenta verificada y activa crea un reporte (batch de la app)', async () => {
      await assertSucceeds(crearReporte(db('bob'), 'bob', HASH.bob, 'nuevo'));
    });

    it('«Sigue ahí» de otra cuenta verificada se acepta', async () => {
      await assertSucceeds(votar(db('bob'), HASH.bob, 1));
    });

    it('«Falso / Ya no está» de otra cuenta verificada se acepta', async () => {
      await assertSucceeds(votar(db('bob'), HASH.bob, -1));
    });
  });

  describe('casos de docs/FIREBASE_SETUP.md §6', () => {
    it('1. visitante sin sesión no puede crear un reporte', async () => {
      const f = anon();
      await assertFails(setDoc(doc(f, 'reports/x'), reporteValido()));
    });

    it('2. cuenta sin verificar no puede reportar', async () => {
      await assertFails(crearReporte(db('dave', { verified: false }), 'dave', HASH.dave, 'x'));
    });

    it('3. correo de otro dominio no puede reportar', async () => {
      await assertFails(
        crearReporte(db('bob', { email: 'bob@gmail.com' }), 'bob', HASH.bob, 'x'),
      );
    });

    it('4. usuario bloqueado no puede votar', async () => {
      await assertFails(votar(db('carol'), HASH.carol, 1));
    });

    it('5. un cliente no puede cambiar su rol, estado ni authorHash', async () => {
      const f = db('bob');
      await assertFails(updateDoc(doc(f, 'users/bob'), { rol: 'admin' }));
      await assertFails(updateDoc(doc(f, 'users/bob'), { estado: 'activo', rol: 'profesor' }));
      await assertFails(updateDoc(doc(f, 'users/bob'), { authorHash: H('9') }));
      await assertFails(updateDoc(doc(f, 'users/carol'), { estado: 'activo' })); // ni desbloquearse
    });

    it('5b. nadie crea su perfil como admin', async () => {
      const f = ctx('nuevo');
      await assertFails(
        setDoc(doc(f, 'users/nuevo'), {
          rol: 'admin', estado: 'activo', authorHash: H('1'), createdAt: Timestamp.now(),
        }),
      );
      await assertSucceeds(
        setDoc(doc(f, 'users/nuevo'), {
          rol: 'estudiante', estado: 'activo', authorHash: H('1'), createdAt: Timestamp.now(),
        }),
      );
    });

    it('6. segundo voto de la misma cuenta al mismo reporte', async () => {
      await assertSucceeds(votar(db('bob'), HASH.bob, 1));
      await assertFails(votar(db('bob'), HASH.bob, 1));
      await assertFails(votar(db('bob'), HASH.bob, -1));
    });

    it('7. el autor no vota su propio reporte', async () => {
      await assertFails(votar(db('alice'), HASH.alice, 1));
    });

    it('8. reportAuthors: otro usuario denegado; admin y autor permitido', async () => {
      await assertFails(getDoc(doc(db('bob'), 'reportAuthors/r1')));
      await assertFails(getDoc(doc(anon(), 'reportAuthors/r1')));
      await assertSucceeds(getDoc(doc(db('admin'), 'reportAuthors/r1')));
      await assertSucceeds(getDoc(doc(db('alice'), 'reportAuthors/r1')));
    });

    it('9. expiraEn distinto de creadoEn + 60 min', async () => {
      const ahora = Date.now();
      const malo = reporteValido({ expiraEn: Timestamp.fromMillis(ahora + 90 * MIN) });
      await assertFails(crearReporte(db('bob'), 'bob', HASH.bob, 'x', malo));
      const corto = reporteValido({ expiraEn: Timestamp.fromMillis(ahora + 59 * MIN) });
      await assertFails(crearReporte(db('bob'), 'bob', HASH.bob, 'y', corto));
    });

    it('10. dos reportes seguidos dentro de 60 s: el segundo se rechaza', async () => {
      const f = db('bob');
      await assertSucceeds(crearReporte(f, 'bob', HASH.bob, 'a'));
      await assertFails(crearReporte(f, 'bob', HASH.bob, 'b'));
    });

    it('10b. pasados 60 s desde su último reporte, la misma cuenta sí puede reportar', async () => {
      await env.withSecurityRulesDisabled(async (c) => {
        await updateDoc(doc(c.firestore(), 'users/bob'), {
          ultimoReporteEn: Timestamp.fromMillis(Date.now() - 61 * 1000),
        });
      });
      await assertSucceeds(crearReporte(db('bob'), 'bob', HASH.bob, 'tras-un-minuto'));
    });

    it('11. no admin no publica ni borra alertas oficiales', async () => {
      const alerta = { tipo: 'oficial', mensaje: 'Prueba', lat: 4.6, lng: -74.0, desde: Timestamp.now() };
      await assertFails(setDoc(doc(db('bob'), 'officialAlerts/a1'), alerta));
      await assertSucceeds(setDoc(doc(db('admin'), 'officialAlerts/a1'), alerta));
      await assertFails(deleteDoc(doc(db('bob'), 'officialAlerts/a1')));
    });

    it('12. admin elimina reporte, publica alerta y bloquea a un no admin', async () => {
      const f = db('admin');
      await assertSucceeds(deleteDoc(doc(f, 'reports/r1')));
      await assertSucceeds(
        setDoc(doc(f, 'officialAlerts/a2'), {
          tipo: 'oficial', mensaje: 'Cierre del Ed. 21', lat: 4.6, lng: -74.0, desde: Timestamp.now(),
        }),
      );
      await assertSucceeds(updateDoc(doc(f, 'users/bob'), { estado: 'bloqueado' }));
    });

    it('12b. admin no bloquea a otro admin ni a sí mismo', async () => {
      const f = db('admin');
      await assertFails(updateDoc(doc(f, 'users/admin2'), { estado: 'bloqueado' }));
      await assertFails(updateDoc(doc(f, 'users/admin'), { estado: 'bloqueado' }));
    });
  });

  describe('endurecimiento adicional', () => {
    it('un cliente no admin no puede borrar un reporte vigente', async () => {
      await assertFails(deleteDoc(doc(db('bob'), 'reports/r1')));
    });

    it('el reporte público no admite campos de autor', async () => {
      const datos = reporteValido({ authorHash: HASH.bob });
      await assertFails(crearReporte(db('bob'), 'bob', HASH.bob, 'x', datos));
    });

    it('no se puede crear un reporte con authorHash ajeno en reportAuthors', async () => {
      await assertFails(crearReporte(db('bob'), 'bob', HASH.alice, 'x'));
    });

    it('un voto no puede cambiar otros campos del reporte', async () => {
      const f = db('bob');
      const b = writeBatch(f);
      b.set(doc(f, 'reports/r1/votes', HASH.bob), { valor: 1, en: Timestamp.now() });
      b.update(doc(f, 'reports/r1'), { confirmaciones: 5 });
      await assertFails(b.commit());
    });

    it('con 3 votos negativos el reporte ya no admite más votos', async () => {
      await env.withSecurityRulesDisabled(async (c) => {
        await updateDoc(doc(c.firestore(), 'reports/r1'), { reportesNegativos: 3 });
      });
      await assertFails(votar(db('bob'), HASH.bob, -1));
    });

    it('un usuario no lee el perfil de otro; el admin sí', async () => {
      await assertFails(getDoc(doc(db('bob'), 'users/alice')));
      await assertSucceeds(getDoc(doc(db('admin'), 'users/alice')));
    });

    it('la bitácora solo la lee el admin y exige quien = uid', async () => {
      await assertFails(getDoc(doc(db('bob'), 'adminActions/x')));
      await assertFails(setDoc(doc(db('admin'), 'adminActions/x'), { quien: 'otro' }));
      await assertSucceeds(setDoc(doc(db('admin'), 'adminActions/x'), { quien: 'admin' }));
    });

    it('colecciones desconocidas están denegadas', async () => {
      await assertFails(getDoc(doc(db('admin'), 'cualquier/cosa')));
      await assertFails(setDoc(doc(db('admin'), 'cualquier/cosa'), { a: 1 }));
    });
  });
});
