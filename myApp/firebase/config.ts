import { initializeApp, getApps, getApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: "AIzaSyA8vUPyQHotiybswHkP5bAXqrXIkggM0Us",
  authDomain: "barakah-new.firebaseapp.com",
  projectId: "barakah-new",
  storageBucket: "barakah-new.firebasestorage.app",
  messagingSenderId: "783945761203",
  appId: "1:783945761203:web:b66000463fd51c8b684bc6",
  measurementId: "G-9XDBPWGXV7"
};

const app = getApps().length === 0
  ? initializeApp(firebaseConfig)
  : getApp();

export const db = getFirestore(app);