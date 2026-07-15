import { initializeApp, getApps } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: "...",
  authDomain: "...",
  projectId: "barakah-new",
  storageBucket: "...",
  messagingSenderId: "...",
  appId: "...",
};

// ✅ لا تغير هذا
const app = getApps().length === 0
  ? initializeApp(firebaseConfig)
  : getApps()[0];

export const db = getFirestore(app);
export const storage = getStorage(app);