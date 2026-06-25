// Tests de las REGLAS ESTRICTAS de Firestore (../firestore.rules) por rol.
//
// Carga las reglas reales que van a la nube y asserta allow/deny contra la
// matriz de permisos del producto (ver plans/fase-2-auth.md). El seed se hace
// con las reglas deshabilitadas (withSecurityRulesDisabled) para evitar el
// chicken-and-egg del bootstrap.
//
// Requisito: el emulador de Firestore corriendo en 127.0.0.1:8080.
//   firebase emulators:start --config firebase.emulator.json --only auth,firestore
// Correr:  cd test_rules && npm install && npm test

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import test, { before, after, beforeEach } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));

// UIDs de prueba: deben coincidir con el id del doc usuarios/{uid}, porque las
// reglas resuelven el rol con get(.../usuarios/$(request.auth.uid)).
const DUENO = 'uid_dueno';
const RECEP = 'uid_recep';
const ESTIL = 'uid_estil'; // estilista vinculado a trabajador_id 'ana'
const INACT = 'uid_inact'; // dueño pero activo:false

let testEnv;

const turnoBase = (trabajadorId) => ({
  fecha: '2026-06-22',
  hora_inicio: '09:00',
  fin_estimado: '09:30',
  trabajador_id: trabajadorId,
  trabajador_nombre: 'X',
  cliente_id: 'c1',
  cliente_nombre: 'Cli',
  servicios: [],
  estado: 'pendiente',
});

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'turnos-rules-test',
    firestore: {
      rules: readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Seed con reglas deshabilitadas (bootstrap).
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'usuarios', DUENO), {
      rol: 'dueno', activo: true, trabajador_id: 'dueno', nombre: 'Dueño', email: 'd@s.test',
    });
    await setDoc(doc(db, 'usuarios', RECEP), {
      rol: 'recepcion', activo: true, trabajador_id: 'luis', nombre: 'Luis', email: 'l@s.test',
    });
    await setDoc(doc(db, 'usuarios', ESTIL), {
      rol: 'estilista', activo: true, trabajador_id: 'ana', nombre: 'Ana', email: 'a@s.test',
    });
    await setDoc(doc(db, 'usuarios', INACT), {
      rol: 'dueno', activo: false, trabajador_id: 'dueno', nombre: 'Inactivo', email: 'i@s.test',
    });
    await setDoc(doc(db, 'servicios', 'corte'), { nombre: 'Corte', precio_referencia: 8000 });
    await setDoc(doc(db, 'clientes', 'c1'), { nombre: 'Cli' });
    await setDoc(doc(db, 'turnos', 't_ana'), turnoBase('ana'));
    await setDoc(doc(db, 'turnos', 't_marta'), turnoBase('marta'));
  });
});

const asDueno = () => testEnv.authenticatedContext(DUENO).firestore();
const asRecep = () => testEnv.authenticatedContext(RECEP).firestore();
const asEstil = () => testEnv.authenticatedContext(ESTIL).firestore();
const asInact = () => testEnv.authenticatedContext(INACT).firestore();
const asAnon = () => testEnv.unauthenticatedContext().firestore();

// ── Lectura: solo staff activo ────────────────────────────────────────────────
test('anónimo NO puede leer servicios', async () => {
  await assertFails(getDoc(doc(asAnon(), 'servicios', 'corte')));
});
test('usuario inactivo NO puede leer servicios', async () => {
  await assertFails(getDoc(doc(asInact(), 'servicios', 'corte')));
});
test('estilista activo SÍ puede leer servicios (catálogo)', async () => {
  await assertSucceeds(getDoc(doc(asEstil(), 'servicios', 'corte')));
});

// ── Servicios: write solo dueño ───────────────────────────────────────────────
test('dueño SÍ puede escribir servicios', async () => {
  await assertSucceeds(setDoc(doc(asDueno(), 'servicios', 'nuevo'), { nombre: 'N' }));
});
test('recepción NO puede escribir servicios', async () => {
  await assertFails(setDoc(doc(asRecep(), 'servicios', 'nuevo'), { nombre: 'N' }));
});
test('estilista NO puede escribir servicios', async () => {
  await assertFails(setDoc(doc(asEstil(), 'servicios', 'nuevo'), { nombre: 'N' }));
});

// ── Usuarios (staff): write solo dueño ────────────────────────────────────────
test('dueño SÍ puede crear usuarios (alta de staff)', async () => {
  await assertSucceeds(setDoc(doc(asDueno(), 'usuarios', 'uid_nuevo'), {
    rol: 'recepcion', activo: true, trabajador_id: 'x', nombre: 'X', email: 'x@s.test',
  }));
});
test('recepción NO puede crear usuarios', async () => {
  await assertFails(setDoc(doc(asRecep(), 'usuarios', 'uid_nuevo'), {
    rol: 'recepcion', activo: true, trabajador_id: 'x', nombre: 'X', email: 'x@s.test',
  }));
});

// ── Clientes: write dueño|recepción, estilista solo lectura ───────────────────
test('recepción SÍ puede escribir clientes', async () => {
  await assertSucceeds(setDoc(doc(asRecep(), 'clientes', 'c2'), { nombre: 'C2' }));
});
test('estilista NO puede escribir clientes (solo lectura)', async () => {
  await assertFails(setDoc(doc(asEstil(), 'clientes', 'c2'), { nombre: 'C2' }));
});
test('estilista SÍ puede leer clientes', async () => {
  await assertSucceeds(getDoc(doc(asEstil(), 'clientes', 'c1')));
});

// ── Turnos: gestión (dueño/recepción) + estilista solo los suyos ──────────────
test('recepción SÍ puede crear turno', async () => {
  await assertSucceeds(setDoc(doc(asRecep(), 'turnos', 't_new'), turnoBase('ana')));
});
test('estilista SÍ puede actualizar un turno SUYO (trabajador_id == ana)', async () => {
  await assertSucceeds(
    setDoc(doc(asEstil(), 'turnos', 't_ana'), { ...turnoBase('ana'), estado: 'en_curso' }),
  );
});
test('estilista NO puede actualizar un turno de OTRO (marta)', async () => {
  await assertFails(
    setDoc(doc(asEstil(), 'turnos', 't_marta'), { ...turnoBase('marta'), estado: 'en_curso' }),
  );
});
test('estilista SÍ puede crear un turno con SU trabajador_id', async () => {
  await assertSucceeds(setDoc(doc(asEstil(), 'turnos', 't_new_ana'), turnoBase('ana')));
});
test('estilista NO puede crear un turno con trabajador_id ajeno', async () => {
  await assertFails(setDoc(doc(asEstil(), 'turnos', 't_new_marta'), turnoBase('marta')));
});
