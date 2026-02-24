/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js');
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyBuFtp9UicSUrYvjbT1JNQ8S-OKv_6Csvs',
  authDomain: 'civiapp-38b51.firebaseapp.com',
  projectId: 'civiapp-38b51',
  storageBucket: 'civiapp-38b51.firebasestorage.app',
  messagingSenderId: '442062945154',
  appId: '1:442062945154:web:080fdd048a96cdb84e6d9b',
  measurementId: 'G-SFSQB8YH04',
});

firebase.messaging();
