import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, signInWithEmailAndPassword } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, doc, getDoc } from 'firebase/firestore';

const app = initializeApp({ apiKey: 'fake-api-key', projectId: 'turnos-salon-163b5' });
const auth = getAuth(app);
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
const db = getFirestore(app);
connectFirestoreEmulator(db, '127.0.0.1', 8080);

try {
  const cred = await signInWithEmailAndPassword(auth, 'dueno@salon.test', 'salon123');
  console.log('LOGIN OK uid:', cred.user.uid);
  const snap = await getDoc(doc(db, 'usuarios', cred.user.uid));
  console.log('usuarios doc existe:', snap.exists(), JSON.stringify(snap.data()));
} catch (e) {
  console.error('LOGIN FAIL:', e.code || e.message);
}
process.exit(0);
