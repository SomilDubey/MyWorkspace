// This file will be auto-generated when you connect Firebase
// For now, it's a placeholder
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for windows');
      case TargetPlatform.linux:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for linux');
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAp99XpIlOfyGXdnFW4BVQgDM8lmkhrNFk',
    appId: '1:962446697416:web:877ab5011d5c7814c796fd',
    messagingSenderId: '962446697416',
    projectId: 'payvault-351d7',
    authDomain: 'payvault-351d7.firebaseapp.com',
    storageBucket: 'payvault-351d7.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAJEa1jKVMOOqDyI6AbFY7ab8O1QCW2W9U',
    appId: '1:962446697416:android:82ce3ac03efde20bc796fd',
    messagingSenderId: '962446697416',
    projectId: 'payvault-351d7',
    storageBucket: 'payvault-351d7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDD8azcKaIXEJ00hVAikf00Jm1bQnwzy6A',
    appId: '1:962446697416:ios:ae043f4305cd4af1c796fd',
    messagingSenderId: '962446697416',
    projectId: 'payvault-351d7',
    storageBucket: 'payvault-351d7.firebasestorage.app',
    iosBundleId: 'com.mycompany.CounterApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_STORAGE_BUCKET',
    iosBundleId: 'com.example.pocketGuard',
  );
}