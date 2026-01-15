import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBiBHhxyIkL2-5cpjn7P796x4LI4iNF1NM',
    authDomain: 'money-manager-jegan-2026.firebaseapp.com',
    projectId: 'money-manager-jegan-2026',
    storageBucket: 'money-manager-jegan-2026.firebasestorage.app',
    messagingSenderId: '678119502568',
    appId: '1:678119502568:web:a2fe30fac315f626eacf5d',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBiBHhxyIkL2-5cpjn7P796x4LI4iNF1NM',
    appId: '1:678119502568:web:a2fe30fac315f626eacf5d',
    messagingSenderId: '678119502568',
    projectId: 'money-manager-jegan-2026',
    storageBucket: 'money-manager-jegan-2026.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBiBHhxyIkL2-5cpjn7P796x4LI4iNF1NM',
    appId: '1:678119502568:web:a2fe30fac315f626eacf5d',
    messagingSenderId: '678119502568',
    projectId: 'money-manager-jegan-2026',
    storageBucket: 'money-manager-jegan-2026.firebasestorage.app',
    iosBundleId: 'com.jegan.moneyManagerApp',
  );
}
