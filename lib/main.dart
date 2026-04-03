import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/auth/auth_providers.dart';
import 'core/purchases/revenue_cat_providers.dart';
import 'core/theme/cookbook_theme.dart';
import 'core/widgets/paper_texture.dart';
import 'firebase_options.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Send all Flutter errors to Crashlytics.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // 2. Anonymous Auth
    await ensureAnonymousAuth();

    // 3. RevenueCat — configure, then link to Firebase UID.
    await configureRevenueCat();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await loginRevenueCat(uid);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(CookbookTheme.edgeToEdgeLight);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    runApp(const ProviderScope(child: MiseEnPicApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class MiseEnPicApp extends StatelessWidget {
  const MiseEnPicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mise en Pic',
      debugShowCheckedModeBanner: false,
      theme: CookbookTheme.light(),
      darkTheme: CookbookTheme.dark(),
      routerConfig: appRouter,
      builder: (context, child) {
        return PaperTextureBackground(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
