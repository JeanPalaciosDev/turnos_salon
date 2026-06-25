// Siembra las cuentas Auth demo + docs usuarios/{uid} + trabajadores/dueno en el
// emulador, usando el MISMO SDK cliente que la app Flutter. Sirve para (a)
// confirmar que el Auth del emulador acepta createUserWithEmailAndPassword y
// (b) desbloquear las pruebas por rol si el seed de la app no llegó a esta parte.
//
// Requisito: emulador corriendo (firebase emulators:start --config firebase.emulator.json).
// Correr:  cd test_rules && node seed_auth.mjs

import { initializeApp } from 'firebase/app';
import {
  getAuth, connectAuthEmulator,
  createUserWithEmailAndPassword, signOut,
} from 'firebase/auth';
import {
  getFirestore, connectFirestoreEmulator, doc, setDoc, serverTimestamp,
} from 'firebase/firestore';

const app = initializeApp({ apiKey: 'fake-api-key', projectId: 'turnos-salon-163b5' });
const auth = getAuth(app);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
const db = getFirestore(app);
connectFirestoreEmulator(db, '127.0.0.1', 8080);

const PASS = 'salon123';
const demo = [
  { email: 'dueno@salon.test', trabajador_id: 'dueno', rol: 'dueno',      nombre: 'Dueño' },
  { email: 'ana@salon.test',   trabajador_id: 'ana',   rol: 'estilista',  nombre: 'Ana' },
  { email: 'marta@salon.test', trabajador_id: 'marta', rol: 'estilista',  nombre: 'Marta' },
  { email: 'luis@salon.test',  trabajador_id: 'luis',  rol: 'recepcion',  nombre: 'Luis' },
];

// trabajador/dueno (el dueño no está en los trabajadores demo del seed base)
await setDoc(doc(db, 'trabajadores', 'dueno'), {
  nombre: 'Dueño', rol: 'dueno', color: '#444444', activo: true, horario: [],
});

for (const u of demo) {
  try {
    const cred = await createUserWithEmailAndPassword(auth, u.email, PASS);
    const uid = cred.user.uid;
    await setDoc(doc(db, 'usuarios', uid), {
      trabajador_id: u.trabajador_id, rol: u.rol, nombre: u.nombre,
      email: u.email, activo: true, created_at: serverTimestamp(),
    });
    console.log(`OK  ${u.email}  (rol ${u.rol}, uid ${uid})`);
  } catch (e) {
    if (e.code === 'auth/email-already-in-use') { console.log(`SKIP ${u.email} (ya existe)`); continue; }
    console.error(`FAIL ${u.email}:`, e.code || e.message);
    throw e;
  }
}
await signOut(auth);
console.log('Seed de cuentas completo.');
process.exit(0);
