importScripts('https://www.gstatic.com/firebasejs/12.17.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.17.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyA8vUPyQHotiybswHkP5bAXqrXIkggM0Us',
  authDomain: 'barakah-new.firebaseapp.com',
  projectId: 'barakah-new',
  storageBucket: 'barakah-new.firebasestorage.app',
  messagingSenderId: '783945761203',
  appId: '1:783945761203:web:b66000463fd51c8b684bc6',
  measurementId: 'G-9XDBPWGXV7',
});

firebase.messaging();

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({type: 'window', includeUncontrolled: true}).then((windows) => {
      for (const windowClient of windows) {
        if ('focus' in windowClient) return windowClient.focus();
      }
      return clients.openWindow('/');
    }),
  );
});
