// Firebase Cloud Messaging service worker.
//
// Fill in the same Firebase web config you added to web/index.html and
// deploy this file at the site root (`/firebase-messaging-sw.js`) so
// the browser accepts it as a registered service worker.
//
// Everything is commented out until real credentials are dropped in —
// otherwise the browser will register a worker that logs FCM errors on
// every page load.

/*
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "REPLACE_ME",
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "0000000000",
  appId: "1:0000000000:web:xxxxxxxxxx"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = (payload.notification && payload.notification.title) || 'Wasit';
  const body  = (payload.notification && payload.notification.body)  || '';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  });
});
*/
